package com.amrosh.Pointchat.keyboard

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity
import android.widget.Button
import android.widget.TextView
import com.amrosh.Pointchat.R

/**
 * Centralized design system for PointChat Native Keyboard.
 * Matches modern Gboard / Material 3 and iOS standards with full-width keys
 * and a horizontal top contact dock.
 */
object KeyboardTheme {

    // --- Colors ---
    const val COLOR_KEY_TEXT = 0xFF1C1C1E.toInt()             // Dark neutral letter text
    const val COLOR_FUNCTION_KEY_TEXT = 0xFF1C1C1E.toInt()    // Function pill text
    const val COLOR_ACCENT_BLUE = 0xFF007AFF.toInt()          // Signature Action Blue
    const val COLOR_TEXT_SECONDARY = 0xFF8E8E93.toInt()       // Subtitle gray
    const val COLOR_TEXT_MUTED = 0xFF48484A.toInt()
    const val COLOR_CHAT_TITLE = 0xFF1C1C1E.toInt()
    const val COLOR_OUTGOING_TEXT = 0xFFFFFFFF.toInt()        // White for outgoing bubble
    const val COLOR_INCOMING_TEXT = 0xFF000000.toInt()        // Black for incoming bubble

    // --- Dimensions ---
    const val KEY_TEXT_SIZE_SP = 21f
    const val KEY_SYMBOL_SIZE_SP = 15f
    const val FUNCTION_TEXT_SIZE_SP = 14f
    const val TOP_AVATAR_SIZE_DP = 34
    const val TOP_ONLINE_DOT_SIZE_DP = 7.5f
    const val MESSAGE_TEXT_SIZE_SP = 14.5f
    const val MESSAGE_MAX_WIDTH_DP = 260

    /**
     * Convert DP to Pixels based on context density.
     */
    fun dpToPx(context: Context, dp: Int): Int {
        val density = context.resources.displayMetrics.density
        return (dp * density).toInt()
    }

    fun dpToPxFloat(context: Context, dp: Float): Int {
        val density = context.resources.displayMetrics.density
        return (dp * density).toInt()
    }

    /**
     * Style standard full-width letter key.
     */
    fun styleLetterKey(
        button: Button,
        text: String,
        context: Context
    ) {
        button.text = text
        button.textSize = KEY_TEXT_SIZE_SP
        button.setTextColor(COLOR_KEY_TEXT)
        button.typeface = Typeface.create("sans-serif", Typeface.NORMAL)
        button.setBackgroundResource(R.drawable.glass_key_cap)
        button.setPadding(0, 0, 0, 0)
        button.isAllCaps = false
        button.stateListAnimator = null
    }

    /**
     * Style function pill key (Shift, Backspace, ?123, Comma, Period, Lang).
     */
    fun styleFunctionKey(
        button: Button,
        context: Context
    ) {
        button.setTextColor(COLOR_FUNCTION_KEY_TEXT)
        button.typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        button.setBackgroundResource(R.drawable.keyboard_key_bg_light)
        button.stateListAnimator = null
    }

    /**
     * Style Action Return / Send pill.
     */
    fun styleActionKey(
        button: Button,
        isSendMode: Boolean,
        context: Context
    ) {
        button.text = if (isSendMode) "Send" else "↵"
        button.textSize = if (isSendMode) 14f else 17f
        button.setTextColor(Color.WHITE)
        button.typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
        button.setBackgroundResource(R.drawable.keyboard_action_bg)
        button.stateListAnimator = null
    }

    /**
     * Style chat message bubble.
     */
    fun styleMessageBubble(
        textView: TextView,
        isMe: Boolean,
        text: String,
        context: Context
    ) {
        textView.text = text
        textView.textSize = MESSAGE_TEXT_SIZE_SP
        textView.setTextColor(if (isMe) COLOR_OUTGOING_TEXT else COLOR_INCOMING_TEXT)
        textView.maxWidth = dpToPx(context, MESSAGE_MAX_WIDTH_DP)
        textView.gravity = Gravity.CENTER_VERTICAL
        textView.typeface = Typeface.create("sans-serif", Typeface.NORMAL)

        val padH = dpToPx(context, 14)
        val padV = dpToPx(context, 8)
        textView.setPadding(padH, padV, padH, padV)

        textView.setBackgroundResource(
            if (isMe) R.drawable.glass_bubble_outgoing else R.drawable.glass_bubble_incoming
        )
    }

    /**
     * Style contact avatar ring when selected vs default.
     */
    fun styleAvatarRing(
        initialView: TextView,
        isSelected: Boolean
    ) {
        initialView.setBackgroundResource(
            if (isSelected) R.drawable.avatar_ring_selected else R.drawable.avatar_ring_default
        )
        initialView.setTextColor(
            if (isSelected) COLOR_ACCENT_BLUE else COLOR_TEXT_MUTED
        )
    }
}
