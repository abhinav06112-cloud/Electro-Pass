package com.example.electro_pass // <-- same package as MainActivity.kt

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

/** The "Yes / No" prompt shown when you pick Electro Pass in the autofill dropdown. */
class AutofillAuthActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val domain = intent.getStringExtra("domain")
        val pkg = intent.getStringExtra("pkg")
        val userId = intent.getParcelableExtra<AutofillId>("user_id")
        val passId = intent.getParcelableExtra<AutofillId>("pass_id")
        val matches = AutofillVault.match(this, domain, pkg)

        if (passId == null || matches.isEmpty()) {
            cancel()
            return
        }
        // "Ask before filling" is off and there is exactly one login
        if (!AutofillVault.confirm(this) && matches.size == 1) {
            deliver(matches, userId, passId)
            return
        }

        val site = domain ?: pkg ?: "this app"
        val theme = android.R.style.Theme_DeviceDefault_Dialog_Alert
        if (matches.size == 1) {
            val m = matches[0]
            AlertDialog.Builder(this, theme)
                .setTitle("Autofill with Electro Pass?")
                .setMessage("Fill ${m.username.ifEmpty { m.name }} on $site?")
                .setPositiveButton("Yes") { _, _ -> deliver(matches, userId, passId) }
                .setNegativeButton("No") { _, _ -> cancel() }
                .setOnCancelListener { cancel() }
                .show()
        } else {
            val labels = matches.map { it.username.ifEmpty { it.name } }.toTypedArray()
            AlertDialog.Builder(this, theme)
                .setTitle("Choose an account for $site")
                .setItems(labels) { _, i -> deliver(listOf(matches[i]), userId, passId) }
                .setOnCancelListener { cancel() }
                .show()
        }
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