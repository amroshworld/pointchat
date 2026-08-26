package com.amrosh.Pointchat.keyboard

import android.content.Context
import android.graphics.Color
import android.inputmethodservice.InputMethodService
import android.os.Build
import android.view.Gravity
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import com.amrosh.Pointchat.R
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import java.util.UUID
import kotlin.concurrent.thread

class PointChatKeyboardService : InputMethodService(), View.OnClickListener {

    private var rootView: View? = null
    private var isShifted = false
    private var isSymbols = false

    private var activeChatId: String? = null
    private var activeChatTitle: String? = null
    private var activeOtherUserId: String? = null
    private var activeChatMessages = mutableListOf<ChatMessageItem>()

    private val topContactPillsMap = mutableMapOf<String, View>()

    private val qwertyRow1 = listOf("q", "w", "e", "r", "t", "y", "u", "i", "o", "p")
    private val qwertyRow2 = listOf("a", "s", "d", "f", "g", "h", "j", "k", "l")
    private val qwertyRow3 = listOf("z", "x", "c", "v", "b", "n", "m")

    private val symbolsRow1 = listOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "0")
    private val symbolsRow2 = listOf("@", "#", "$", "%", "&", "-", "+", "(", ")")
    private val symbolsRow3 = listOf("*", "\"", "'", ":", ";", "!", "?")

    private val letterButtons = mutableListOf<Button>()
    private var shiftButton: Button? = null
    private var actionButton: Button? = null

    data class ChatMessageItem(val sender: String, val text: String, val isMe: Boolean)
    data class ContactInfo(
        val chatId: String,
        val title: String,
        val otherUserId: String,
        val isOnline: Boolean,
        val unreadCount: Int,
        val lastMessage: String
    )

    override fun onCreateInputView(): View {
        val view = LayoutInflater.from(this).inflate(R.layout.pointchat_keyboard_view, null)
        rootView = view

        setupTopToolbar(view)
        setupKeypad(view)
        setupStreamControls(view)
        setupWindowInsets(view)
        loadContactsIntoTopBar()

        return view
    }

    private fun setupWindowInsets(view: View) {
        val insetFooter = view.findViewById<View>(R.id.inset_footer)
        view.setOnApplyWindowInsetsListener { _, insets ->
            val bottom = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                insets.getInsets(android.view.WindowInsets.Type.navigationBars()).bottom
            } else {
                insets.systemWindowInsetBottom
            }
            val minInset = KeyboardTheme.dpToPx(this, 28)
            val targetHeight = if (bottom > minInset) bottom else minInset
            insetFooter?.layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                targetHeight
            )
            insets
        }
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        rootView?.let { loadContactsIntoTopBar() }
    }

    // ------------------------------------------------------------------
    // TOP TOOLBAR & HORIZONTAL CONTACTS DOCK
    // ------------------------------------------------------------------

    private fun setupTopToolbar(view: View) {
        view.findViewById<View>(R.id.top_brand_button)?.setOnClickListener {
            toggleChatPopupWithFirstContact()
        }
        view.findViewById<View>(R.id.top_globe_button)?.setOnClickListener {
            switchAwayIme()
        }
    }

    private fun loadContactsIntoTopBar() {
        val root = rootView ?: return
        val container = root.findViewById<LinearLayout>(R.id.top_contacts_container) ?: return
        container.removeAllViews()
        topContactPillsMap.clear()

        val contacts = getContacts()
        for (c in contacts) {
            val pillView = buildTopContactPill(c)
            topContactPillsMap[c.chatId] = pillView
            container.addView(pillView)
        }
    }

    private fun getContacts(): List<ContactInfo> {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val chatsJson = prefs.getString("flutter.pointchat_kb_recent_chats", "[]") ?: "[]"
        val result = mutableListOf<ContactInfo>()
        try {
            var array = JSONArray(chatsJson)
            if (array.length() == 0) {
                array = JSONArray().apply {
                    put(JSONObject().apply {
                        put("title", "Amr Taha")
                        put("chatId", "c_taha")
                        put("otherUserId", "u_taha")
                        put("isOnline", true)
                        put("unreadCount", 2)
                        put("lastMessage", "Hi! Good morning.")
                    })
                    put(JSONObject().apply {
                        put("title", "Sara")
                        put("chatId", "c_sara")
                        put("otherUserId", "u_sara")
                        put("isOnline", true)
                        put("unreadCount", 5)
                        put("lastMessage", "Can we meet later?")
                    })
                    put(JSONObject().apply {
                        put("title", "Direct")
                        put("chatId", "c_dir")
                        put("otherUserId", "u_dir")
                        put("isOnline", false)
                        put("unreadCount", 0)
                        put("lastMessage", "Sure thing!")
                    })
                }
            }
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                result.add(
                    ContactInfo(
                        chatId = obj.optString("chatId", ""),
                        title = obj.optString("title", "Chat"),
                        otherUserId = obj.optString("otherUserId", ""),
                        isOnline = obj.optBoolean("isOnline", false),
                        unreadCount = obj.optInt("unreadCount", 0),
                        lastMessage = obj.optString("lastMessage", "")
                    )
                )
            }
        } catch (e: Exception) {}
        return result
    }

    private fun buildTopContactPill(c: ContactInfo): View {
        val title = c.title
        val initial = if (title.isNotEmpty()) title.substring(0, 1).uppercase(Locale.US) else "C"
        val isSelected = (c.chatId == activeChatId)

        val avatarSize = KeyboardTheme.dpToPx(this, KeyboardTheme.TOP_AVATAR_SIZE_DP)
        val frame = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(avatarSize, avatarSize)
        }

        val initialView = TextView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            text = initial
            textSize = 13.5f
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
            setBackgroundResource(if (isSelected) R.drawable.avatar_ring_selected else R.drawable.avatar_ring_default)
            setTextColor(if (isSelected) KeyboardTheme.COLOR_ACCENT_BLUE else KeyboardTheme.COLOR_TEXT_MUTED)
        }
        frame.addView(initialView)

        val dotSize = KeyboardTheme.dpToPxFloat(this, KeyboardTheme.TOP_ONLINE_DOT_SIZE_DP)
        val dotView = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(dotSize, dotSize, Gravity.BOTTOM or Gravity.END).apply {
                setMargins(0, 0, KeyboardTheme.dpToPx(this@PointChatKeyboardService, 1), KeyboardTheme.dpToPx(this@PointChatKeyboardService, 1))
            }
            setBackgroundResource(
                if (c.isOnline) R.drawable.online_dot_green else R.drawable.online_dot_red
            )
        }
        frame.addView(dotView)

        if (c.unreadCount > 0) {
            val badgeHeight = KeyboardTheme.dpToPx(this, 13)
            val badgeView = TextView(this).apply {
                layoutParams = FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    badgeHeight,
                    Gravity.TOP or Gravity.END
                )
                text = if (c.unreadCount > 9) "9+" else c.unreadCount.toString()
                textSize = 7.5f
                setTextColor(Color.WHITE)
                setBackgroundResource(R.drawable.unread_badge_bg)
                gravity = Gravity.CENTER
                setPadding(KeyboardTheme.dpToPx(this@PointChatKeyboardService, 3), 0, KeyboardTheme.dpToPx(this@PointChatKeyboardService, 3), 0)
            }
            frame.addView(badgeView)
        }

        val labelView = TextView(this).apply {
            text = if (title.length > 8) title.substring(0, 7) + ".." else title
            textSize = 12f
            setTextColor(if (isSelected) KeyboardTheme.COLOR_ACCENT_BLUE else KeyboardTheme.COLOR_KEY_TEXT)
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { setMargins(KeyboardTheme.dpToPx(this@PointChatKeyboardService, 5), 0, 0, 0) }
        }

        val pillLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundResource(R.drawable.contact_top_pill_bg)
            this.isSelected = isSelected
            val padH = KeyboardTheme.dpToPx(this@PointChatKeyboardService, 4)
            val padV = KeyboardTheme.dpToPx(this@PointChatKeyboardService, 2)
            val marginH = KeyboardTheme.dpToPx(this@PointChatKeyboardService, 3)
            setPadding(padH, padV, KeyboardTheme.dpToPx(this@PointChatKeyboardService, 8), padV)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                KeyboardTheme.dpToPx(this@PointChatKeyboardService, 38)
            ).apply { setMargins(marginH, 0, marginH, 0) }
            addView(frame)
            addView(labelView)
            isClickable = true
            isFocusable = true
            setOnClickListener {
                selectContactAndShowStream(c)
            }
        }

        return pillLayout
    }

    private fun toggleChatPopupWithFirstContact() {
        val root = rootView ?: return
        val popup = root.findViewById<View>(R.id.popup_container) ?: return
        if (popup.visibility == View.VISIBLE) {
            minimizeChatStream()
        } else {
            val contacts = getContacts()
            if (contacts.isNotEmpty()) {
                selectContactAndShowStream(contacts[0])
            }
        }
    }

    private fun switchAwayIme() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            switchToPreviousInputMethod()
        } else {
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showInputMethodPicker()
        }
    }

    // ------------------------------------------------------------------
    // ACTIVE CHAT STREAM (EXPAND & COLLAPSE)
    // ------------------------------------------------------------------

    private fun setupStreamControls(view: View) {
        view.findViewById<TextView>(R.id.popup_close)?.setOnClickListener {
            minimizeChatStream()
        }
        view.findViewById<Button>(R.id.popup_send)?.setOnClickListener {
            sendFromPopup()
        }
        view.findViewById<EditText>(R.id.popup_input)?.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_SEND) {
                sendFromPopup()
                true
            } else false
        }
    }

    private fun minimizeChatStream() {
        activeChatId = null
        activeChatTitle = null
        activeOtherUserId = null
        activeChatMessages.clear()

        val root = rootView ?: return
        root.findViewById<View>(R.id.popup_container)?.visibility = View.GONE

        actionButton?.let { KeyboardTheme.styleActionKey(it, isSendMode = false, context = this) }
        loadContactsIntoTopBar()
    }

    private fun selectContactAndShowStream(c: ContactInfo) {
        activeChatId = c.chatId
        activeChatTitle = c.title
        activeOtherUserId = c.otherUserId

        loadContactsIntoTopBar()

        val root = rootView ?: return
        val popup = root.findViewById<View>(R.id.popup_container) ?: return

        root.findViewById<TextView>(R.id.popup_title)?.text = c.title
        root.findViewById<View>(R.id.popup_online_dot)?.setBackgroundResource(
            if (c.isOnline) R.drawable.online_dot_green else R.drawable.online_dot_red
        )

        activeChatMessages.clear()
        activeChatMessages.add(ChatMessageItem(c.title, "Hey there!", false))
        activeChatMessages.add(ChatMessageItem("Me", "Hey, what's up?", true))
        activeChatMessages.add(ChatMessageItem(c.title, if (c.lastMessage.isNotEmpty()) c.lastMessage else "Can we meet later?", false))

        renderStreamMessages()
        popup.visibility = View.VISIBLE

        actionButton?.let { KeyboardTheme.styleActionKey(it, isSendMode = true, context = this) }
        scrollMessagesToBottom()
        root.findViewById<EditText>(R.id.popup_input)?.requestFocus()
    }

    private fun renderStreamMessages() {
        val root = rootView ?: return
        val stack = root.findViewById<LinearLayout>(R.id.popup_messages_stack) ?: return
        stack.removeAllViews()

        for (m in activeChatMessages) {
            val bubble = TextView(this).apply {
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )
            }
            KeyboardTheme.styleMessageBubble(bubble, isMe = m.isMe, text = m.text, context = this)

            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = if (m.isMe) Gravity.END else Gravity.START
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                ).apply {
                    val marginV = KeyboardTheme.dpToPx(this@PointChatKeyboardService, 3)
                    setMargins(0, marginV, 0, marginV)
                }
                addView(bubble)
            }
            stack.addView(row)
        }
    }

    // ------------------------------------------------------------------
    // DIRECT SENDING
    // ------------------------------------------------------------------

    private fun sendFromPopup() {
        val input = rootView?.findViewById<EditText>(R.id.popup_input)
        val text = input?.text?.toString()?.trim().orEmpty()
        if (text.isNotEmpty()) {
            input?.setText("")
            sendMessageToActiveChat(text)
            return
        }
        trySendHostText()
    }

    private fun trySendHostText() {
        val ic = currentInputConnection
        if (activeChatId != null && ic != null) {
            val textBefore = ic.getTextBeforeCursor(300, 0)?.toString()?.trim() ?: ""
            if (textBefore.isNotEmpty()) {
                sendMessageToActiveChat(textBefore)
                ic.deleteSurroundingText(textBefore.length, 0)
            }
        }
    }

    private fun handleActionOrSend() {
        if (activeChatId != null) {
            sendFromPopup()
            return
        }

        val ic = currentInputConnection ?: return
        ic.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_ENTER))
        ic.sendKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_ENTER))
    }

    private fun sendMessageToActiveChat(text: String) {
        val chatId = activeChatId ?: return
        activeChatMessages.add(ChatMessageItem("Me", text, true))
        renderStreamMessages()
        scrollMessagesToBottom()

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val userId = prefs.getString("flutter.pointchat_kb_userId", "") ?: ""
        val userName = prefs.getString("flutter.pointchat_kb_userName", "User") ?: "User"
        val endpoint = prefs.getString("flutter.pointchat_kb_endpoint", "https://fra.cloud.appwrite.io/v1") ?: ""
        val projectId = prefs.getString("flutter.pointchat_kb_project", "69a6d89d0007909f06f7") ?: ""
        val databaseId = prefs.getString("flutter.pointchat_kb_database", "pointchat_db") ?: "pointchat_db"

        if (userId.isEmpty() || endpoint.isEmpty()) return

        thread {
            try {
                val url = URL("$endpoint/databases/$databaseId/collections/messages/documents")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("X-Appwrite-Project", projectId)
                    doOutput = true
                    connectTimeout = 5000
                    readTimeout = 5000
                }

                val payload = JSONObject().apply {
                    put("documentId", "msg_" + UUID.randomUUID().toString().substring(0, 16))
                    put("data", JSONObject().apply {
                        put("chatId", chatId)
                        put("senderId", userId)
                        put("senderName", userName)
                        put("senderPhotoUrl", "")
                        put("text", text)
                        put("type", "text")
                        put("isRead", false)
                        put("readBy", "{\"$userId\": true}")
                    })
                }

                OutputStreamWriter(conn.outputStream).use { writer ->
                    writer.write(payload.toString())
                    writer.flush()
                }

                conn.responseCode
                conn.disconnect()
            } catch (e: Exception) {}
        }
    }

    private fun scrollMessagesToBottom() {
        val root = rootView ?: return
        val stack = root.findViewById<LinearLayout>(R.id.popup_messages_stack) ?: return
        stack.post {
            val parent = stack.parent
            if (parent is ScrollView) {
                parent.fullScroll(View.FOCUS_DOWN)
            }
        }
    }

    // ------------------------------------------------------------------
    // FULL-WIDTH KEYPAD SETUP
    // ------------------------------------------------------------------

    private fun setupKeypad(view: View) {
        letterButtons.clear()

        val row1 = view.findViewById<LinearLayout>(R.id.row1)
        val row2 = view.findViewById<LinearLayout>(R.id.row2)
        val row3Letters = view.findViewById<LinearLayout>(R.id.row3_letters)

        populateRow(row1, qwertyRow1)
        populateRow(row2, qwertyRow2)
        populateRow(row3Letters, qwertyRow3)

        shiftButton = view.findViewById<Button>(R.id.key_shift)?.apply {
            KeyboardTheme.styleFunctionKey(this, this@PointChatKeyboardService)
            setOnClickListener {
                isShifted = !isShifted
                isSelected = isShifted
                updateLettersCase()
            }
        }

        view.findViewById<Button>(R.id.key_backspace)?.apply {
            KeyboardTheme.styleFunctionKey(this, this@PointChatKeyboardService)
            setOnClickListener {
                val ic = currentInputConnection ?: return@setOnClickListener
                val selected = ic.getSelectedText(0)
                if (selected != null && selected.isNotEmpty()) {
                    ic.commitText("", 1)
                } else {
                    val deleted = ic.deleteSurroundingText(1, 0)
                    if (!deleted) {
                        ic.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_DEL))
                        ic.sendKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_DEL))
                    }
                }
            }
        }

        view.findViewById<Button>(R.id.key_symbols)?.apply {
            KeyboardTheme.styleFunctionKey(this, this@PointChatKeyboardService)
            setOnClickListener {
                isSymbols = !isSymbols
                text = if (isSymbols) "ABC" else "?123"
                reloadKeypadMatrix()
            }
        }

        view.findViewById<Button>(R.id.key_lang)?.apply {
            KeyboardTheme.styleFunctionKey(this, this@PointChatKeyboardService)
        }

        view.findViewById<Button>(R.id.key_space)?.apply {
            setOnClickListener {
                currentInputConnection?.commitText(" ", 1)
            }
        }

        view.findViewById<Button>(R.id.key_period)?.apply {
            KeyboardTheme.styleFunctionKey(this, this@PointChatKeyboardService)
            setOnClickListener {
                currentInputConnection?.commitText(".", 1)
            }
        }

        view.findViewById<Button>(R.id.key_comma)?.apply {
            KeyboardTheme.styleFunctionKey(this, this@PointChatKeyboardService)
            setOnClickListener {
                currentInputConnection?.commitText(",", 1)
            }
        }

        actionButton = view.findViewById<Button>(R.id.key_enter)?.apply {
            KeyboardTheme.styleActionKey(this, isSendMode = (activeChatId != null), context = this@PointChatKeyboardService)
            setOnClickListener {
                handleActionOrSend()
            }
        }
    }

    private fun populateRow(container: LinearLayout, keys: List<String>) {
        container.removeAllViews()
        val marginH = KeyboardTheme.dpToPx(this, 2)
        for (k in keys) {
            val btn = Button(this).apply {
                layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1.0f).apply {
                    setMargins(marginH, 0, marginH, 0)
                }
                val displayText = if (isShifted) k.uppercase(Locale.US) else k
                KeyboardTheme.styleLetterKey(this, displayText, this@PointChatKeyboardService)
                setOnClickListener {
                    currentInputConnection?.commitText(this.text.toString(), 1)
                    if (isShifted) {
                        isShifted = false
                        shiftButton?.isSelected = false
                        updateLettersCase()
                    }
                }
            }
            letterButtons.add(btn)
            container.addView(btn)
        }
    }

    private fun reloadKeypadMatrix() {
        val root = rootView ?: return
        letterButtons.clear()

        val row1 = root.findViewById<LinearLayout>(R.id.row1)
        val row2 = root.findViewById<LinearLayout>(R.id.row2)
        val row3Letters = root.findViewById<LinearLayout>(R.id.row3_letters)

        if (isSymbols) {
            populateRow(row1, symbolsRow1)
            populateRow(row2, symbolsRow2)
            populateRow(row3Letters, symbolsRow3)
        } else {
            populateRow(row1, qwertyRow1)
            populateRow(row2, qwertyRow2)
            populateRow(row3Letters, qwertyRow3)
        }
    }

    private fun updateLettersCase() {
        for (btn in letterButtons) {
            val current = btn.text.toString()
            btn.text = if (isShifted) current.uppercase(Locale.US) else current.lowercase(Locale.US)
        }
    }

    override fun onClick(v: View?) {}
}
