package com.example.electro_pass // <-- same package as MainActivity.kt

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Encrypted copy of the logins that the autofill service is allowed to use. */
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

    fun save(ctx: Context, json: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val enc = cipher.doFinal(json.toByteArray(Charsets.UTF_8))
        val blob = cipher.iv + enc
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString("blob", Base64.encodeToString(blob, Base64.NO_WRAP)).apply()
    }

    private fun load(ctx: Context): JSONObject? {
        return try {
            val s = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("blob", null)
                ?: return null
            val raw = Base64.decode(s, Base64.NO_WRAP)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, raw.copyOfRange(0, 12)))
            JSONObject(String(cipher.doFinal(raw.copyOfRange(12, raw.size)), Charsets.UTF_8))
        } catch (e: Exception) {
            null
        }
    }

    fun confirm(ctx: Context): Boolean = load(ctx)?.optBoolean("confirm", true) ?: true

    private fun host(s: String): String =
        s.trim().lowercase()
            .removePrefix("https://").removePrefix("http://").removePrefix("www.")
            .substringBefore('/').substringBefore('?').substringBefore(':')

    fun match(ctx: Context, domain: String?, pkg: String?): List<Login> {
        val items = load(ctx)?.optJSONArray("items") ?: return emptyList()
        val want = domain?.takeIf { it.isNotBlank() }?.let { host(it) } ?: pkg?.let { APP_DOMAINS[it] }
        val out = ArrayList<Login>()
        for (i in 0 until items.length()) {
            val o = items.getJSONObject(i)
            val u = host(o.optString("url"))
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
}