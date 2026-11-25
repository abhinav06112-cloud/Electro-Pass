// Electro Pass - one-command Android setup.
//
// Run from your Flutter project folder:
//     dart tool/setup_android.dart
//
// It installs the native Android autofill code, registers the service,
// sets the app name to "Electro Pass" and the minimum Android version to 8.

import 'dart:io';

const _mainActivity = r'''package __PACKAGE__

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import android.view.autofill.AutofillManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Hide the app from screenshots and the recent-apps preview (Settings can turn this off)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "electro/autofill")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ping" -> result.success(true)
                    "isEnabled" -> {
                        val m = getSystemService(AutofillManager::class.java)
                        result.success(m != null && m.hasEnabledAutofillServices())
                    }
                    "openSettings" -> {
                        try {
                            val i = Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE)
                            i.data = Uri.parse("package:$packageName")
                            startActivity(i)
                        } catch (e: Exception) {
                            try {
                                startActivity(Intent(Settings.ACTION_SETTINGS))
                            } catch (_: Exception) {
                            }
                        }
                        result.success(true)
                    }
                    "sync" -> {
                        AutofillVault.save(this, call.arguments as String)
                        result.success(true)
                    }
                    "takePending" -> result.success(AutofillVault.takePending(this))
                    "setSecure" -> {
                        val on = call.arguments as? Boolean ?: true
                        runOnUiThread {
                            if (on) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
''';
const _vault = r'''package __PACKAGE__

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Encrypted copy of the logins the autofill service may use, plus saved-from-prompt logins. */
object AutofillVault {
    private const val ALIAS = "electro_autofill_key"
    private const val PREFS = "electro_autofill"

    data class Login(val name: String, val username: String, val password: String, val url: String)

    // package id -> website, so apps (not only browsers) can match a login
    private val APP_DOMAINS = mapOf(
        "com.instagram.android" to "instagram.com",
        "com.facebook.katana" to "facebook.com",
        "com.twitter.android" to "x.com",
        "com.spotify.music" to "spotify.com",
        "com.linkedin.android" to "linkedin.com",
        "com.netflix.mediaclient" to "netflix.com",
        "com.discord" to "discord.com",
        "com.github.android" to "github.com",
        "com.whatsapp" to "whatsapp.com",
        "com.snapchat.android" to "snapchat.com",
        "com.reddit.frontpage" to "reddit.com",
        "com.pinterest" to "pinterest.com",
        "com.google.android.gm" to "google.com",
        "com.google.android.youtube" to "youtube.com",
        "com.amazon.mShop.android.shopping" to "amazon.com",
    )

    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(
            KeyGenParameterSpec.Builder(
                ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return gen.generateKey()
    }

    private fun encrypt(plain: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val enc = cipher.doFinal(plain.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(cipher.iv + enc, Base64.NO_WRAP)
    }

    private fun decrypt(s: String): String? {
        return try {
            val raw = Base64.decode(s, Base64.NO_WRAP)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, raw.copyOfRange(0, 12)))
            String(cipher.doFinal(raw.copyOfRange(12, raw.size)), Charsets.UTF_8)
        } catch (e: Exception) {
            null
        }
    }

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(ctx: Context, json: String) {
        prefs(ctx).edit().putString("blob", encrypt(json)).apply()
    }

    private fun load(ctx: Context): JSONObject? {
        val s = prefs(ctx).getString("blob", null) ?: return null
        val d = decrypt(s) ?: return null
        return try {
            JSONObject(d)
        } catch (e: Exception) {
            null
        }
    }

    /** Every saved login, A to Z (used when nothing matches the site/app). */
    fun all(ctx: Context): List<Login> {
        val items = load(ctx)?.optJSONArray("items") ?: return emptyList()
        val out = ArrayList<Login>()
        for (i in 0 until items.length()) {
            val o = items.getJSONObject(i)
            out.add(
                Login(
                    o.optString("name"), o.optString("username"),
                    o.optString("password"), o.optString("url")
                )
            )
        }
        return out.sortedBy { it.name.lowercase() }
    }

    fun confirm(ctx: Context): Boolean = load(ctx)?.optBoolean("confirm", true) ?: true

    fun hostOf(s: String): String =
        s.trim().lowercase()
            .removePrefix("https://").removePrefix("http://").removePrefix("www.")
            .substringBefore('/').substringBefore('?').substringBefore(':')

    fun match(ctx: Context, domain: String?, pkg: String?): List<Login> {
        val items = load(ctx)?.optJSONArray("items") ?: return emptyList()
        val want = domain?.takeIf { it.isNotBlank() }?.let { hostOf(it) } ?: pkg?.let { APP_DOMAINS[it] }
        val out = ArrayList<Login>()
        for (i in 0 until items.length()) {
            val o = items.getJSONObject(i)
            val u = hostOf(o.optString("url"))
            if (u.isEmpty()) continue
            val ok = if (want != null) {
                want == u || want.endsWith(".$u") || u.endsWith(".$want")
            } else {
                pkg != null && u == pkg.lowercase()
            }
            if (ok) {
                out.add(
                    Login(
                        o.optString("name"), o.optString("username"),
                        o.optString("password"), o.optString("url")
                    )
                )
            }
        }
        return out
    }

    // ---- logins the user chose to save from Android's "Save password?" prompt ----
    @Synchronized
    fun addPending(ctx: Context, name: String, username: String, password: String, url: String) {
        val p = prefs(ctx)
        val current = p.getString("pending", null)?.let { decrypt(it) }?.let {
            try {
                JSONArray(it)
            } catch (e: Exception) {
                null
            }
        } ?: JSONArray()
        current.put(
            JSONObject().put("name", name).put("username", username)
                .put("password", password).put("url", url)
        )
        p.edit().putString("pending", encrypt(current.toString())).apply()
    }

    @Synchronized
    fun takePending(ctx: Context): String {
        val p = prefs(ctx)
        val s = p.getString("pending", null) ?: return "[]"
        p.edit().remove("pending").apply()
        return decrypt(s) ?: "[]"
    }
}
''';
const _service = r'''package __PACKAGE__

import android.app.PendingIntent
import android.app.assist.AssistStructure
import android.content.Intent
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveInfo
import android.service.autofill.SaveRequest
import android.text.InputType
import android.view.View
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.widget.RemoteViews

class ElectroAutofillService : AutofillService() {

    private class Parsed {
        var domain: String? = null
        var username: AutofillId? = null
        var password: AutofillId? = null
        var userValue: String? = null
        var passValue: String? = null
    }

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback
    ) {
        val structure = request.fillContexts.last().structure
        val pkg = structure.activityComponent?.packageName
        if (pkg == packageName) {
            callback.onSuccess(null)
            return
        }
        val parsed = parse(structure)
        val passId = parsed.password
        if (passId == null) {
            callback.onSuccess(null)
            return
        }

        val builder = FillResponse.Builder()

        // Ask "Save password?" after the user signs in somewhere new.
        val save = SaveInfo.Builder(SaveInfo.SAVE_DATA_TYPE_PASSWORD, arrayOf(passId))
        parsed.username?.let { save.setOptionalIds(arrayOf(it)) }
        save.setDescription("Save this login to Electro Pass?")
        save.setFlags(SaveInfo.FLAG_SAVE_ON_ALL_VIEWS_INVISIBLE)
        builder.setSaveInfo(save.build())

        val matches = AutofillVault.match(this, parsed.domain, pkg)
        if (matches.isNotEmpty() && !AutofillVault.confirm(this)) {
            // "Ask before filling" is off: one tap on the suggestion fills it
            for (l in matches.take(5)) {
                val row = RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
                    setTextViewText(android.R.id.text1, "Electro Pass  ·  ${l.username.ifEmpty { l.name }}")
                }
                val ds = Dataset.Builder(row)
                parsed.username?.let { ds.setValue(it, AutofillValue.forText(l.username)) }
                ds.setValue(passId, AutofillValue.forText(l.password))
                builder.addDataset(ds.build())
            }
        } else {
            // Confirm mode (or nothing matched): the user picks in a small dialog.
            // If nothing matched the site/app, the dialog lists ALL logins.
            val pool = if (matches.isEmpty()) AutofillVault.all(this) else matches
            if (pool.isNotEmpty()) {
                val ids = listOfNotNull(parsed.username, passId).toTypedArray()
                val text = when {
                    matches.isEmpty() -> "Electro Pass  ·  choose a login"
                    matches.size == 1 -> "Electro Pass  ·  ${matches[0].username.ifEmpty { matches[0].name }}"
                    else -> "Electro Pass  ·  ${matches.size} logins"
                }
                val label = RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
                    setTextViewText(android.R.id.text1, text)
                }
                val intent = Intent(this, AutofillAuthActivity::class.java).apply {
                    putExtra("domain", parsed.domain)
                    putExtra("pkg", pkg)
                    putExtra("user_id", parsed.username)
                    putExtra("pass_id", passId)
                    putExtra("all", matches.isEmpty())
                }
                val pi = PendingIntent.getActivity(
                    this, 1001, intent,
                    PendingIntent.FLAG_CANCEL_CURRENT or PendingIntent.FLAG_MUTABLE
                )
                builder.setAuthentication(ids, pi.intentSender, label)
            }
        }
        callback.onSuccess(builder.build())
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        try {
            val structure = request.fillContexts.last().structure
            val parsed = parse(structure)
            val pass = parsed.passValue
            if (!pass.isNullOrEmpty()) {
                val pkg = structure.activityComponent?.packageName
                val domain = parsed.domain
                val url = if (!domain.isNullOrBlank()) AutofillVault.hostOf(domain) else (pkg ?: "")
                AutofillVault.addPending(
                    this, friendlyName(domain, pkg), parsed.userValue ?: "", pass, url
                )
            }
        } catch (e: Exception) {
            // ignore: nothing to save
        }
        callback.onSuccess()
    }

    private fun friendlyName(domain: String?, pkg: String?): String {
        if (!domain.isNullOrBlank()) {
            val parts = AutofillVault.hostOf(domain).split('.')
            val base = if (parts.size >= 2) parts[parts.size - 2] else parts[0]
            return base.replaceFirstChar { it.uppercase() }
        }
        if (pkg != null) {
            try {
                return packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0))
                    .toString()
            } catch (e: Exception) {
            }
            return pkg
        }
        return "Login"
    }

    // ---------- find the username / password fields ----------
    private fun parse(structure: AssistStructure): Parsed {
        val p = Parsed()
        var lastText: AutofillId? = null
        var lastValue: String? = null

        fun visit(n: AssistStructure.ViewNode) {
            n.webDomain?.let { if (p.domain == null && it.isNotBlank()) p.domain = it }
            val id = n.autofillId
            if (id != null && n.autofillType == View.AUTOFILL_TYPE_TEXT) {
                val value: String? = n.autofillValue?.let {
                    if (it.isText) it.textValue.toString() else null
                } ?: n.text?.toString()
                val hints = n.autofillHints?.toList().orEmpty()
                val htmlPassword = n.htmlInfo?.attributes
                    ?.any { it.first == "type" && it.second == "password" } == true
                val isPass = hints.contains(View.AUTOFILL_HINT_PASSWORD) ||
                    isPasswordInput(n.inputType) || htmlPassword
                val isUser = hints.contains(View.AUTOFILL_HINT_USERNAME) ||
                    hints.contains(View.AUTOFILL_HINT_EMAIL_ADDRESS)
                if (isPass) {
                    if (p.password == null) {
                        p.password = id
                        p.passValue = value
                        if (p.username == null) {
                            p.username = lastText
                            p.userValue = lastValue
                        }
                    }
                } else {
                    if (isUser && p.username == null) {
                        p.username = id
                        p.userValue = value
                    }
                    lastText = id
                    lastValue = value
                }
            }
            for (i in 0 until n.childCount) visit(n.getChildAt(i))
        }

        for (i in 0 until structure.windowNodeCount) {
            visit(structure.getWindowNodeAt(i).rootViewNode)
        }
        return p
    }

    private fun isPasswordInput(t: Int): Boolean {
        val cls = t and InputType.TYPE_MASK_CLASS
        val v = t and InputType.TYPE_MASK_VARIATION
        return (cls == InputType.TYPE_CLASS_TEXT && (
            v == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                v == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD ||
                v == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD)) ||
            (cls == InputType.TYPE_CLASS_NUMBER && v == InputType.TYPE_NUMBER_VARIATION_PASSWORD)
    }
}
''';
const _auth = r'''package __PACKAGE__

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.os.Bundle
import android.service.autofill.Dataset
import android.service.autofill.FillResponse
import android.view.autofill.AutofillId
import android.view.autofill.AutofillManager
import android.view.autofill.AutofillValue
import android.widget.RemoteViews

/** The prompt shown when you pick Electro Pass in the autofill dropdown. */
class AutofillAuthActivity : Activity() {

    private val dialogTheme = android.R.style.Theme_DeviceDefault_Dialog_Alert

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val domain = intent.getStringExtra("domain")
        val pkg = intent.getStringExtra("pkg")
        val showAll = intent.getBooleanExtra("all", false)
        val userId = intent.getParcelableExtra<AutofillId>("user_id")
        val passId = intent.getParcelableExtra<AutofillId>("pass_id")
        val matches = AutofillVault.match(this, domain, pkg)
        val everyone = AutofillVault.all(this)

        if (passId == null || (matches.isEmpty() && everyone.isEmpty())) {
            cancel()
            return
        }
        val site = domain ?: pkg ?: "this app"

        // Nothing matched this site/app: let the user pick from ALL logins.
        if (showAll || matches.isEmpty()) {
            chooseFromAll(everyone, site, userId, passId)
            return
        }
        // "Ask before filling" is off and there is exactly one login
        if (!AutofillVault.confirm(this) && matches.size == 1) {
            deliver(matches, userId, passId)
            return
        }

        if (matches.size == 1) {
            val m = matches[0]
            AlertDialog.Builder(this, dialogTheme)
                .setTitle("Autofill with Electro Pass?")
                .setMessage("Fill ${m.username.ifEmpty { m.name }} on $site?")
                .setPositiveButton("Yes") { _, _ -> deliver(matches, userId, passId) }
                .setNegativeButton("No") { _, _ -> cancel() }
                .setNeutralButton("Other login") { _, _ -> chooseFromAll(everyone, site, userId, passId) }
                .setOnCancelListener { cancel() }
                .show()
        } else {
            val labels = (matches.map { it.username.ifEmpty { it.name } } + "Other logins…").toTypedArray()
            AlertDialog.Builder(this, dialogTheme)
                .setTitle("Choose an account for $site")
                .setItems(labels) { _, i ->
                    if (i == matches.size) {
                        chooseFromAll(everyone, site, userId, passId)
                    } else {
                        deliver(listOf(matches[i]), userId, passId)
                    }
                }
                .setOnCancelListener { cancel() }
                .show()
        }
    }

    private fun chooseFromAll(
        list: List<AutofillVault.Login>, site: String, userId: AutofillId?, passId: AutofillId
    ) {
        if (list.isEmpty()) {
            cancel()
            return
        }
        val labels = list.map {
            "${it.name}  ·  ${it.username.ifEmpty { "(no username)" }}"
        }.toTypedArray()
        AlertDialog.Builder(this, dialogTheme)
            .setTitle("Choose a login for $site")
            .setItems(labels) { _, i -> deliver(listOf(list[i]), userId, passId) }
            .setOnCancelListener { cancel() }
            .show()
    }

    private fun cancel() {
        setResult(RESULT_CANCELED)
        finish()
    }

    private fun deliver(list: List<AutofillVault.Login>, userId: AutofillId?, passId: AutofillId) {
        val response = FillResponse.Builder()
        for (l in list) {
            val label = RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
                setTextViewText(android.R.id.text1, l.username.ifEmpty { l.name })
            }
            val ds = Dataset.Builder(label)
            if (userId != null) ds.setValue(userId, AutofillValue.forText(l.username))
            ds.setValue(passId, AutofillValue.forText(l.password))
            response.addDataset(ds.build())
        }
        setResult(
            RESULT_OK,
            Intent().putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, response.build())
        )
        finish()
    }
}
''';

const _xml = '''<?xml version="1.0" encoding="utf-8"?>
<autofill-service xmlns:android="http://schemas.android.com/apk/res/android" />
''';

String _manifestBlock(String pkg) => '''
        <service
            android:name="$pkg.ElectroAutofillService"
            android:label="Electro Pass"
            android:permission="android.permission.BIND_AUTOFILL_SERVICE"
            android:exported="true">
            <intent-filter>
                <action android:name="android.service.autofill.AutofillService" />
            </intent-filter>
            <meta-data
                android:name="android.autofill"
                android:resource="@xml/autofill_service" />
        </service>
        <activity
            android:name="$pkg.AutofillAuthActivity"
            android:exported="false"
            android:theme="@android:style/Theme.Translucent.NoTitleBar" />
''';

File? _findMainActivity(Directory main) {
  for (final dirName in ['kotlin', 'java']) {
    final d = Directory('${main.path}/$dirName');
    if (!d.existsSync()) continue;
    for (final e in d.listSync(recursive: true)) {
      if (e is File &&
          (e.path.endsWith('MainActivity.kt') || e.path.endsWith('MainActivity.java'))) {
        return e;
      }
    }
  }
  return null;
}

void _step(String s) => stdout.writeln('  - $s');

void main() {
  final root = Directory.current.path;
  final main = Directory('$root/android/app/src/main');
  if (!main.existsSync()) {
    stderr.writeln('Could not find android/app/src/main.');
    stderr.writeln('Run this from your Flutter project folder (the one with pubspec.yaml).');
    exit(1);
  }
  stdout.writeln('Setting up Electro Pass for Android...');

  // 1. Kotlin files, using YOUR package name
  final activity = _findMainActivity(main);
  if (activity == null) {
    stderr.writeln('Could not find MainActivity.kt / MainActivity.java.');
    exit(1);
  }
  final text = activity.readAsStringSync();
  final m = RegExp(r'^\s*package\s+([\w.]+)', multiLine: true).firstMatch(text);
  if (m == null) {
    stderr.writeln('Could not read the package name from ${activity.path}.');
    exit(1);
  }
  final pkg = m.group(1)!;
  final dir = activity.parent.path;
  if (activity.path.endsWith('.java')) {
    activity.renameSync('${activity.path}.bak');
  } else if (!File('${activity.path}.bak').existsSync()) {
    activity.copySync('${activity.path}.bak');
  }
  void write(String path, String content) =>
      File(path).writeAsStringSync(content.replaceAll('__PACKAGE__', pkg));
  write('$dir/MainActivity.kt', _mainActivity);
  write('$dir/AutofillVault.kt', _vault);
  write('$dir/ElectroAutofillService.kt', _service);
  write('$dir/AutofillAuthActivity.kt', _auth);
  _step('Kotlin files written (package $pkg)');

  // 2. xml resource
  final xmlDir = Directory('${main.path}/res/xml')..createSync(recursive: true);
  File('${xmlDir.path}/autofill_service.xml').writeAsStringSync(_xml);
  _step('res/xml/autofill_service.xml written');

  // 3. manifest: app name + service
  final mf = File('${main.path}/AndroidManifest.xml');
  var manifest = mf.readAsStringSync();
  manifest = manifest.replaceFirst(
      RegExp(r'android:label="[^"]*"'), 'android:label="Electro Pass"');
  if (!manifest.contains('ElectroAutofillService')) {
    if (!manifest.contains('</application>')) {
      stderr.writeln('AndroidManifest.xml has no </application> tag.');
      exit(1);
    }
    manifest = manifest.replaceFirst('</application>', '${_manifestBlock(pkg)}    </application>');
    _step('autofill service registered in AndroidManifest.xml');
  } else {
    _step('autofill service already registered');
  }
  mf.writeAsStringSync(manifest);
  _step('app name set to "Electro Pass"');

  // 4. minimum Android version 8.0 (API 26) for autofill
  for (final name in ['build.gradle.kts', 'build.gradle']) {
    final f = File('$root/android/app/$name');
    if (!f.existsSync()) continue;
    final before = f.readAsStringSync();
    final after = before.replaceAllMapped(
      RegExp(r'(minSdk(?:Version)?\s*=?\s*)(flutter\.minSdkVersion|\d+)'),
      (mm) {
        final v = mm.group(2)!;
        if (v.startsWith('flutter')) return '${mm.group(1)}26';
        return int.parse(v) < 26 ? '${mm.group(1)}26' : mm.group(0)!;
      },
    );
    if (after != before) {
      f.writeAsStringSync(after);
      _step('minSdk set to 26 in $name');
    }
  }

  // 5. names for web + iOS (skipped if those folders do not exist)
  final index = File('$root/web/index.html');
  if (index.existsSync()) {
    var s = index.readAsStringSync();
    s = s.replaceAll(RegExp(r'<title>[^<]*</title>'), '<title>Electro Pass</title>');
    s = s.replaceAllMapped(
        RegExp(r'(name="apple-mobile-web-app-title"\s+content=")[^"]*(")'),
        (mm) => '${mm.group(1)}Electro Pass${mm.group(2)}');
    index.writeAsStringSync(s);
    _step('web/index.html name updated');
  }
  final manifestJson = File('$root/web/manifest.json');
  if (manifestJson.existsSync()) {
    var s = manifestJson.readAsStringSync();
    s = s.replaceAllMapped(RegExp(r'("(?:name|short_name)"\s*:\s*")[^"]*(")'),
        (mm) => '${mm.group(1)}Electro Pass${mm.group(2)}');
    manifestJson.writeAsStringSync(s);
    _step('web/manifest.json name updated');
  }
  final plist = File('$root/ios/Runner/Info.plist');
  if (plist.existsSync()) {
    var s = plist.readAsStringSync();
    s = s.replaceAllMapped(
        RegExp(r'(<key>(?:CFBundleDisplayName|CFBundleName)</key>\s*<string>)[^<]*(</string>)'),
        (mm) => '${mm.group(1)}Electro Pass${mm.group(2)}');
    plist.writeAsStringSync(s);
    _step('ios Info.plist name updated');
  }

  stdout.writeln('');
  stdout.writeln('Done. Now:');
  stdout.writeln('  1. Stop the running app completely');
  stdout.writeln('  2. flutter clean');
  stdout.writeln('  3. flutter run   (full rebuild, hot reload is not enough)');
  stdout.writeln('  4. Open the Autofill tab and pick Electro Pass');
}