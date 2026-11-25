package com.example.electro_pass // <-- same package as MainActivity.kt

import android.app.PendingIntent
import android.app.assist.AssistStructure
import android.content.Intent
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.text.InputType
import android.view.View
import android.view.autofill.AutofillId
import android.widget.RemoteViews

class ElectroAutofillService : AutofillService() {

    private class Parsed {
        var domain: String? = null
        var username: AutofillId? = null
        var password: AutofillId? = null
    }

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback
    ) {
        val structure = request.fillContexts.last().structure
        val parsed = parse(structure)
        val passId = parsed.password
        if (passId == null) {
            callback.onSuccess(null)
            return
        }
        val pkg = structure.activityComponent?.packageName
        val matches = AutofillVault.match(this, parsed.domain, pkg)
        if (matches.isEmpty()) {
            callback.onSuccess(null)
            return
        }

        val ids = listOfNotNull(parsed.username, passId).toTypedArray()
        val label = RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
            setTextViewText(android.R.id.text1, "Electro Pass  ·  ${matches.size} login(s)")
        }
        val intent = Intent(this, AutofillAuthActivity::class.java).apply {
            putExtra("domain", parsed.domain)
            putExtra("pkg", pkg)
            putExtra("user_id", parsed.username)
            putExtra("pass_id", passId)
        }
        val pi = PendingIntent.getActivity(
            this, 1001, intent,
            PendingIntent.FLAG_CANCEL_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        callback.onSuccess(
            FillResponse.Builder().setAuthentication(ids, pi.intentSender, label).build()
        )
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        callback.onSuccess()
    }

    // ---------- find the username / password fields ----------
    private fun parse(structure: AssistStructure): Parsed {
        val p = Parsed()
        var lastText: AutofillId? = null

        fun visit(n: AssistStructure.ViewNode) {
            n.webDomain?.let { if (p.domain == null && it.isNotBlank()) p.domain = it }
            val id = n.autofillId
            if (id != null && n.autofillType == View.AUTOFILL_TYPE_TEXT) {
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
                        if (p.username == null) p.username = lastText
                    }
                } else {
                    if (isUser && p.username == null) p.username = id
                    lastText = id
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