import UIKit

class KeyboardViewController: UIInputViewController {

    private var isShifted = false
    private var isSymbols = false

    private var activeChatId: String?
    private var activeChatTitle: String?
    private var activeOtherUserId: String?
    private var activeChatMessages: [(sender: String, text: String, isMe: Bool)] = []
    private var avatarButtonMap: [String: UIButton] = [:]

    private let qwertyRow1 = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
    private let qwertyRow2 = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
    private let qwertyRow3 = ["z", "x", "c", "v", "b", "n", "m"]

    private let symbolsRow1 = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    private let symbolsRow2 = ["@", "#", "$", "%", "&", "-", "+", "(", ")"]
    private let symbolsRow3 = ["*", "\"", "'", ":", ";", "!", "?"]

    private var letterButtons: [UIButton] = []
    private var actionButton: UIButton?

    private let mainContainer = UIStackView()
    private let bodySplitStack = UIStackView()
    private let keypadStack = UIStackView()
    private let avatarColumn = UIView()
    private let avatarStack = UIStackView()

    // Floating Capsule Stack (Pyramid Depth Fade)
    private let capsuleStack = UIStackView()
    private let capsule1 = UIView()
    private let capsule2 = UIView()
    private let capsule3 = UIView()
    private let capsule4 = UIView()

    private let cap1Label = UILabel()
    private let cap2Label = UILabel()
    private let cap3Label = UILabel()
    private let cap4Label = UILabel()
    private let activeNameLabel = UILabel()
    private let activeAvatarInitial = UILabel()
    private let activeOnlineDot = UIView()

    private let row1Stack = UIStackView()
    private let row2Stack = UIStackView()
    private let row3LettersStack = UIStackView()
    private var shiftButton: UIButton?
    private var symbolsButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadAvatarColumn()
    }

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1.0)

        mainContainer.axis = .vertical
        mainContainer.spacing = 4
        mainContainer.distribution = .fill
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainContainer)

        NSLayoutConstraint.activate([
            mainContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            mainContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            mainContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            mainContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4)
        ])

        // 1. Floating Capsule Stack
        setupCapsuleStack()
        mainContainer.addArrangedSubview(capsuleStack)

        // 2. Main Body Split Stack (Keypad + Right Avatar Column)
        bodySplitStack.axis = .horizontal
        bodySplitStack.spacing = 4
        bodySplitStack.distribution = .fill
        mainContainer.addArrangedSubview(bodySplitStack)

        setupKeypad()
        setupAvatarColumn()

        bodySplitStack.addArrangedSubview(keypadStack)
        bodySplitStack.addArrangedSubview(avatarColumn)
    }

    private func setupCapsuleStack() {
        capsuleStack.axis = .vertical
        capsuleStack.spacing = 3
        capsuleStack.alignment = .center
        capsuleStack.isHidden = true

        // Capsule 1 (Top / Oldest, Narrowest, Highest Transparency)
        buildPillCapsule(capsule1, label: cap1Label, width: 180, alpha: 0.45, fontSize: 10)
        // Capsule 2 (Mid-High)
        buildPillCapsule(capsule2, label: cap2Label, width: 230, alpha: 0.65, fontSize: 11)
        // Capsule 3 (Mid-Low)
        buildPillCapsule(capsule3, label: cap3Label, width: 280, alpha: 0.85, fontSize: 11.5)
        // Capsule 4 (Bottom / Latest - Full Width with Contact Info & Close button)
        buildBottomCapsule()

        capsuleStack.addArrangedSubview(capsule1)
        capsuleStack.addArrangedSubview(capsule2)
        capsuleStack.addArrangedSubview(capsule3)
        capsuleStack.addArrangedSubview(capsule4)
    }

    private func buildPillCapsule(_ container: UIView, label: UILabel, width: CGFloat, alpha: CGFloat, fontSize: CGFloat) {
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor(red: 0.08, green: 0.11, blue: 0.18, alpha: alpha)
        container.layer.cornerRadius = 12
        container.layer.borderColor = UIColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 0.2).cgColor
        container.layer.borderWidth = 0.8
        container.isHidden = true

        label.font = UIFont.systemFont(ofSize: fontSize)
        label.textColor = UIColor(white: 0.9, alpha: 1.0)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: width),
            container.heightAnchor.constraint(equalToConstant: 24),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8)
        ])
    }

    private func buildBottomCapsule() {
        capsule4.translatesAutoresizingMaskIntoConstraints = false
        capsule4.backgroundColor = UIColor(red: 0.08, green: 0.11, blue: 0.18, alpha: 0.95)
        capsule4.layer.cornerRadius = 16
        capsule4.layer.borderColor = UIColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 0.4).cgColor
        capsule4.layer.borderWidth = 1.2

        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        capsule4.addSubview(row)

        NSLayoutConstraint.activate([
            capsule4.heightAnchor.constraint(equalToConstant: 36),
            row.topAnchor.constraint(equalTo: capsule4.topAnchor, constant: 2),
            row.bottomAnchor.constraint(equalTo: capsule4.bottomAnchor, constant: -2),
            row.leadingAnchor.constraint(equalTo: capsule4.leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: capsule4.trailingAnchor, constant: -8)
        ])

        // Initial Avatar Circle
        let avatarBox = UIView()
        avatarBox.translatesAutoresizingMaskIntoConstraints = false
        avatarBox.layer.cornerRadius = 12
        avatarBox.backgroundColor = UIColor(red: 0.01, green: 0.52, blue: 0.78, alpha: 1.0)
        NSLayoutConstraint.activate([
            avatarBox.widthAnchor.constraint(equalToConstant: 24),
            avatarBox.heightAnchor.constraint(equalToConstant: 24)
        ])

        activeAvatarInitial.textColor = .white
        activeAvatarInitial.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        activeAvatarInitial.textAlignment = .center
        activeAvatarInitial.translatesAutoresizingMaskIntoConstraints = false
        avatarBox.addSubview(activeAvatarInitial)
        NSLayoutConstraint.activate([
            activeAvatarInitial.centerXAnchor.constraint(equalTo: avatarBox.centerXAnchor),
            activeAvatarInitial.centerYAnchor.constraint(equalTo: avatarBox.centerYAnchor)
        ])

        activeOnlineDot.translatesAutoresizingMaskIntoConstraints = false
        activeOnlineDot.layer.cornerRadius = 3.5
        activeOnlineDot.backgroundColor = UIColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1.0)
        avatarBox.addSubview(activeOnlineDot)
        NSLayoutConstraint.activate([
            activeOnlineDot.widthAnchor.constraint(equalToConstant: 7),
            activeOnlineDot.heightAnchor.constraint(equalToConstant: 7),
            activeOnlineDot.trailingAnchor.constraint(equalTo: avatarBox.trailingAnchor),
            activeOnlineDot.bottomAnchor.constraint(equalTo: avatarBox.bottomAnchor)
        ])

        // Info V-Stack
        let infoStack = UIStackView()
        infoStack.axis = .vertical
        infoStack.spacing = 1

        activeNameLabel.font = UIFont.systemFont(ofSize: 10.5, weight: .bold)
        activeNameLabel.textColor = UIColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 1.0)

        cap4Label.font = UIFont.systemFont(ofSize: 11.5, weight: .medium)
        cap4Label.textColor = .white
        cap4Label.lineBreakMode = .byTruncatingTail

        infoStack.addArrangedSubview(activeNameLabel)
        infoStack.addArrangedSubview(cap4Label)

        // Close Button
        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("✕", for: .normal)
        closeBtn.setTitleColor(UIColor(white: 0.7, alpha: 1.0), for: .normal)
        closeBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        closeBtn.backgroundColor = UIColor(red: 0.15, green: 0.18, blue: 0.24, alpha: 1.0)
        closeBtn.layer.cornerRadius = 10
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeBtn.widthAnchor.constraint(equalToConstant: 20),
            closeBtn.heightAnchor.constraint(equalToConstant: 20)
        ])
        closeBtn.addTarget(self, action: #selector(deselectChat), for: .touchUpInside)

        row.addArrangedSubview(avatarBox)
        row.addArrangedSubview(infoStack)
        row.addArrangedSubview(closeBtn)
    }

    private func setupAvatarColumn() {
        avatarColumn.backgroundColor = UIColor(red: 0.06, green: 0.09, blue: 0.15, alpha: 1.0)
        avatarColumn.layer.cornerRadius = 10
        avatarColumn.layer.borderColor = UIColor(red: 0.15, green: 0.20, blue: 0.30, alpha: 1.0).cgColor
        avatarColumn.layer.borderWidth = 1.0
        avatarColumn.translatesAutoresizingMaskIntoConstraints = false
        avatarColumn.widthAnchor.constraint(equalToConstant: 46).isActive = true

        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        avatarColumn.addSubview(scroll)

        avatarStack.axis = .vertical
        avatarStack.spacing = 8
        avatarStack.alignment = .center
        avatarStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(avatarStack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: avatarColumn.topAnchor, constant: 4),
            scroll.bottomAnchor.constraint(equalTo: avatarColumn.bottomAnchor, constant: -4),
            scroll.leadingAnchor.constraint(equalTo: avatarColumn.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: avatarColumn.trailingAnchor),

            avatarStack.topAnchor.constraint(equalTo: scroll.topAnchor),
            avatarStack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            avatarStack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            avatarStack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            avatarStack.widthAnchor.constraint(equalTo: scroll.widthAnchor)
        ])
    }

    private func setupKeypad() {
        keypadStack.axis = .vertical
        keypadStack.spacing = 4
        letterButtons.removeAll()

        row1Stack.axis = .horizontal
        row1Stack.spacing = 2.5
        row1Stack.distribution = .fillEqually

        row2Stack.axis = .horizontal
        row2Stack.spacing = 2.5
        row2Stack.distribution = .fillEqually
        row2Stack.layoutMargins = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        row2Stack.isLayoutMarginsRelativeArrangement = true

        row3LettersStack.axis = .horizontal
        row3LettersStack.spacing = 2.5
        row3LettersStack.distribution = .fillEqually

        let row3Stack = UIStackView()
        row3Stack.axis = .horizontal
        row3Stack.spacing = 2.5
        row3Stack.distribution = .fill

        let shift = createSpecialKey(title: "⇧", weight: 1.4)
        shift.addTarget(self, action: #selector(didTapShift), for: .touchUpInside)
        self.shiftButton = shift

        let backspace = createSpecialKey(title: "⌫", weight: 1.4)
        backspace.addTarget(self, action: #selector(didTapBackspace), for: .touchUpInside)

        row3Stack.addArrangedSubview(shift)
        row3Stack.addArrangedSubview(row3LettersStack)
        row3Stack.addArrangedSubview(backspace)

        // Row 4: Symbols + Globe + Space + Return/Send
        let row4Stack = UIStackView()
        row4Stack.axis = .horizontal
        row4Stack.spacing = 2.5
        row4Stack.distribution = .fill

        let symbols = createSpecialKey(title: "?123", weight: 1.3)
        symbols.addTarget(self, action: #selector(didTapSymbols), for: .touchUpInside)
        self.symbolsButton = symbols

        let globe = createSpecialKey(title: "🌐", weight: 1.0)
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        let space = createSpecialKey(title: "space", weight: 4.4)
        space.addTarget(self, action: #selector(didTapSpace), for: .touchUpInside)

        let dot = createSpecialKey(title: ".", weight: 0.9)
        dot.addTarget(self, action: #selector(didTapDot), for: .touchUpInside)

        let ret = createSpecialKey(title: "↵", weight: 2.2, isAction: true)
        ret.addTarget(self, action: #selector(handleActionOrSend), for: .touchUpInside)
        self.actionButton = ret

        row4Stack.addArrangedSubview(symbols)
        row4Stack.addArrangedSubview(globe)
        row4Stack.addArrangedSubview(space)
        row4Stack.addArrangedSubview(dot)
        row4Stack.addArrangedSubview(ret)

        [row1Stack, row2Stack, row3Stack, row4Stack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.heightAnchor.constraint(equalToConstant: 44).isActive = true
            keypadStack.addArrangedSubview($0)
        }

        populateKeys(qwertyRow1, in: row1Stack)
        populateKeys(qwertyRow2, in: row2Stack)
        populateKeys(qwertyRow3, in: row3LettersStack)
    }

    private func populateKeys(_ keys: [String], in stack: UIStackView) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for k in keys {
            let btn = UIButton(type: .system)
            let title = isShifted ? k.uppercased() : k
            btn.setTitle(title, for: .normal)
            btn.setTitleColor(UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1.0), for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
            btn.backgroundColor = UIColor(red: 0.09, green: 0.12, blue: 0.20, alpha: 1.0)
            btn.layer.cornerRadius = 7
            btn.layer.borderColor = UIColor(red: 0.16, green: 0.21, blue: 0.31, alpha: 1.0).cgColor
            btn.layer.borderWidth = 0.8
            btn.addTarget(self, action: #selector(didTapKey(_:)), for: .touchUpInside)
            letterButtons.append(btn)
            stack.addArrangedSubview(btn)
        }
    }

    private func createSpecialKey(title: String, weight: CGFloat, isAction: Bool = false) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        btn.backgroundColor = isAction
            ? UIColor(red: 0.01, green: 0.52, blue: 0.78, alpha: 1.0)
            : UIColor(red: 0.09, green: 0.12, blue: 0.20, alpha: 1.0)
        btn.layer.cornerRadius = 7
        btn.layer.borderColor = isAction
            ? UIColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 1.0).cgColor
            : UIColor(red: 0.16, green: 0.21, blue: 0.31, alpha: 1.0).cgColor
        btn.layer.borderWidth = 1.0
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
        return btn
    }

    private func loadAvatarColumn() {
        avatarStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        avatarButtonMap.removeAll()

        var chats = SharedStorage.shared.getRecentChats()
        if chats.isEmpty {
            chats = [
                KeyboardRecentChat(chatId: "demo_1", title: "Sarah", avatar: nil, otherUserId: "u1", lastMessage: "Can you send the files?", lastMessageTime: nil, lastMessageSenderId: "u1", unreadCount: 2, isGroup: false, isOnline: true, participants: nil),
                KeyboardRecentChat(chatId: "demo_2", title: "Mohamed", avatar: nil, otherUserId: "u2", lastMessage: "Call me later", lastMessageTime: nil, lastMessageSenderId: "u2", unreadCount: 5, isGroup: false, isOnline: false, participants: nil),
                KeyboardRecentChat(chatId: "demo_3", title: "Khaled", avatar: nil, otherUserId: "u3", lastMessage: "All good, see you tomorrow!", lastMessageTime: nil, lastMessageSenderId: "u3", unreadCount: 1, isGroup: false, isOnline: true, participants: nil),
            ]
        }

        for chat in chats {
            let btn = UIButton(type: .system)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.layer.cornerRadius = 18
            btn.backgroundColor = UIColor(red: 0.12, green: 0.16, blue: 0.23, alpha: 1.0)
            btn.layer.borderColor = UIColor(red: 0.20, green: 0.25, blue: 0.33, alpha: 1.0).cgColor
            btn.layer.borderWidth = 1.5

            let initial = chat.title.prefix(1).uppercased()
            btn.setTitle(initial, for: .normal)
            btn.setTitleColor(.white, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)

            NSLayoutConstraint.activate([
                btn.widthAnchor.constraint(equalToConstant: 36),
                btn.heightAnchor.constraint(equalToConstant: 36)
            ])

            // Online Dot
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.layer.cornerRadius = 3.5
            dot.backgroundColor = (chat.isOnline == true)
                ? UIColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1.0)
                : UIColor(white: 0.5, alpha: 1.0)
            btn.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 7),
                dot.heightAnchor.constraint(equalToConstant: 7),
                dot.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -1),
                dot.bottomAnchor.constraint(equalTo: btn.bottomAnchor, constant: -1)
            ])

            // Unread Count Badge
            let unread = chat.unreadCount ?? 0
            if unread > 0 {
                let badge = UILabel()
                badge.text = unread > 9 ? "9+" : "\(unread)"
                badge.textColor = .white
                badge.font = UIFont.systemFont(ofSize: 8, weight: .bold)
                badge.backgroundColor = UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1.0)
                badge.layer.cornerRadius = 6
                badge.layer.masksToBounds = true
                badge.textAlignment = .center
                badge.translatesAutoresizingMaskIntoConstraints = false
                btn.addSubview(badge)
                NSLayoutConstraint.activate([
                    badge.heightAnchor.constraint(equalToConstant: 12),
                    badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 12),
                    badge.topAnchor.constraint(equalTo: btn.topAnchor, constant: -2),
                    badge.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: 2)
                ])
            }

            btn.addAction(UIAction { [weak self] _ in
                self?.selectChat(chat)
            }, for: .touchUpInside)

            avatarButtonMap[chat.chatId] = btn
            avatarStack.addArrangedSubview(btn)
        }
    }

    private func selectChat(_ chat: KeyboardRecentChat) {
        activeChatId = chat.chatId
        activeChatTitle = chat.title
        activeOtherUserId = chat.otherUserId

        // Update glowing rings on avatars
        for (id, btn) in avatarButtonMap {
            if id == chat.chatId {
                btn.layer.borderColor = UIColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 1.0).cgColor
                btn.layer.borderWidth = 2.5
            } else {
                btn.layer.borderColor = UIColor(red: 0.20, green: 0.25, blue: 0.33, alpha: 1.0).cgColor
                btn.layer.borderWidth = 1.5
            }
        }

        activeNameLabel.text = chat.title
        activeAvatarInitial.text = String(chat.title.prefix(1)).uppercased()
        activeOnlineDot.backgroundColor = (chat.isOnline == true)
            ? UIColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1.0)
            : UIColor(white: 0.5, alpha: 1.0)

        activeChatMessages.removeAll()
        if let last = chat.lastMessage, !last.isEmpty {
            activeChatMessages.append((sender: chat.title, text: "Hey, did you see the update?", isMe: false))
            activeChatMessages.append((sender: "Me", text: "Checking it now!", isMe: true))
            activeChatMessages.append((sender: chat.title, text: last, isMe: false))
        } else {
            activeChatMessages.append((sender: chat.title, text: "Connected via PointChat", isMe: false))
        }

        renderCapsules()
        capsuleStack.isHidden = false
        actionButton?.setTitle("🚀 Send", for: .normal)
    }

    @objc private func deselectChat() {
        activeChatId = nil
        activeChatTitle = nil
        activeOtherUserId = nil
        activeChatMessages.clear()
        capsuleStack.isHidden = true
        actionButton?.setTitle("↵", for: .normal)

        for (_, btn) in avatarButtonMap {
            btn.layer.borderColor = UIColor(red: 0.20, green: 0.25, blue: 0.33, alpha: 1.0).cgColor
            btn.layer.borderWidth = 1.5
        }
    }

    private func renderCapsules() {
        [capsule1, capsule2, capsule3].forEach { $0.isHidden = true }
        let count = activeChatMessages.count

        if count >= 1 {
            let m = activeChatMessages[count - 1]
            cap4Label.text = m.text
        }
        if count >= 2 {
            let m = activeChatMessages[count - 2]
            cap3Label.text = m.text
            capsule3.isHidden = false
        }
        if count >= 3 {
            let m = activeChatMessages[count - 3]
            cap2Label.text = m.text
            capsule2.isHidden = false
        }
        if count >= 4 {
            let m = activeChatMessages[count - 4]
            cap1Label.text = m.text
            capsule1.isHidden = false
        }
    }

    @objc private func handleActionOrSend() {
        if let chatId = activeChatId,
           let textBefore = textDocumentProxy.documentContextBeforeInput,
           !textBefore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let msg = textBefore.trimmingCharacters(in: .whitespacesAndNewlines)
            activeChatMessages.append((sender: "Me", text: msg, isMe: true))
            renderCapsules()

            AppwriteLightClient.shared.sendMessage(chatId: chatId, text: msg) { _, _ in }
            for _ in 0..<msg.count {
                textDocumentProxy.deleteBackward()
            }
            return
        }

        textDocumentProxy.insertText("\n")
    }

    @objc private func didTapKey(_ sender: UIButton) {
        guard let char = sender.title(for: .normal) else { return }
        textDocumentProxy.insertText(char)
        if isShifted {
            isShifted = false
            updateLettersCase()
        }
    }

    @objc private func didTapShift() {
        isShifted = !isShifted
        updateLettersCase()
    }

    @objc private func didTapBackspace() {
        textDocumentProxy.deleteBackward()
    }

    @objc private func didTapSymbols() {
        isSymbols = !isSymbols
        symbolsButton?.setTitle(isSymbols ? "ABC" : "?123", for: .normal)
        reloadKeypadMatrix()
    }

    @objc private func didTapSpace() {
        textDocumentProxy.insertText(" ")
    }

    @objc private func didTapDot() {
        textDocumentProxy.insertText(".")
    }

    private func updateLettersCase() {
        for btn in letterButtons {
            if let current = btn.title(for: .normal) {
                btn.setTitle(isShifted ? current.uppercased() : current.lowercased(), for: .normal)
            }
        }
    }

    private func reloadKeypadMatrix() {
        letterButtons.removeAll()
        if isSymbols {
            populateKeys(symbolsRow1, in: row1Stack)
            populateKeys(symbolsRow2, in: row2Stack)
            populateKeys(symbolsRow3, in: row3LettersStack)
        } else {
            populateKeys(qwertyRow1, in: row1Stack)
            populateKeys(qwertyRow2, in: row2Stack)
            populateKeys(qwertyRow3, in: row3LettersStack)
        }
    }
}
