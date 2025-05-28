// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleMessage {
    // Định nghĩa cấu trúc dữ liệu cho một tin nhắn
    struct Message {
        uint id;                  // ID duy nhất của tin nhắn
        string content;           // Nội dung của tin nhắn
        address sender;           // Địa chỉ của người gửi tin nhắn
        uint timestamp;           // Thời gian tin nhắn được gửi (Unix timestamp)
        uint lastEditedTimestamp; // Thời gian chỉnh sửa cuối cùng (0 nếu chưa chỉnh sửa)
        bool isDeleted;           // Đánh dấu tin nhắn đã bị xóa (xóa mềm - không thực sự xóa khỏi blockchain)
        uint likesCount;          // Số lượt thích của tin nhắn
    }

    // Mảng công khai để lưu trữ tất cả các tin nhắn
    Message[] public messages;

    // Biến để theo dõi ID tiếp theo sẽ được gán cho một tin nhắn mới
    uint public nextMessageId = 0;

    // Mapping để theo dõi người dùng nào đã thích tin nhắn nào
    // messageId => userAddress => hasLiked
    mapping(uint => mapping(address => bool)) private userLikes;

    // Định nghĩa các sự kiện sẽ được phát ra khi có các hành động mới
    event NewMessage(uint indexed messageId, address indexed sender, string content, uint timestamp);
    event MessageEdited(uint indexed messageId, address indexed editor, string newContent, uint timestamp);
    event MessageDeleted(uint indexed messageId, address indexed deleter, uint timestamp);
    event MessageLiked(uint indexed messageId, address indexed liker, uint timestamp);
    event MessageUnliked(uint indexed messageId, address indexed unliker, uint timestamp);

    /**
     * @dev Gửi một tin nhắn mới lên blockchain.
     * @param _content Nội dung của tin nhắn muốn gửi.
     */
    function postMessage(string memory _content) public {
        require(bytes(_content).length > 0, unicode"Nội dung tin nhắn không được rỗng.");

        // Tạo một đối tượng Message mới với các giá trị mặc định cho chức năng mới
        Message memory newMessage = Message({
            id: nextMessageId,
            content: _content,
            sender: msg.sender,
            timestamp: block.timestamp,
            lastEditedTimestamp: 0, // Ban đầu chưa chỉnh sửa
            isDeleted: false,       // Ban đầu chưa bị xóa
            likesCount: 0           // Ban đầu chưa có lượt thích
        });

        // Thêm tin nhắn mới vào cuối mảng `messages`
        messages.push(newMessage);

        // Phát ra sự kiện NewMessage để thông báo về tin nhắn mới
        emit NewMessage(nextMessageId, msg.sender, _content, block.timestamp);

        // Tăng ID cho tin nhắn tiếp theo
        nextMessageId++;
    }

    /**
     * @dev Chỉnh sửa nội dung của một tin nhắn đã tồn tại.
     * Chỉ người gửi gốc mới có thể chỉnh sửa tin nhắn của họ.
     * @param _id ID của tin nhắn muốn chỉnh sửa.
     * @param _newContent Nội dung mới của tin nhắn.
     */
    function editMessage(uint _id, string memory _newContent) public {
        require(_id < messages.length, unicode"ID tin nhắn nằm ngoài giới hạn.");
        require(messages[_id].sender == msg.sender, unicode"Chỉ người gửi mới có thể chỉnh sửa tin nhắn này.");
        require(bytes(_newContent).length > 0, unicode"Nội dung mới không được rỗng.");
        require(!messages[_id].isDeleted, unicode"Không thể chỉnh sửa tin nhắn đã bị xóa.");

        messages[_id].content = _newContent;
        messages[_id].lastEditedTimestamp = block.timestamp;

        emit MessageEdited(_id, msg.sender, _newContent, block.timestamp);
    }

    /**
     * @dev Đánh dấu một tin nhắn là đã bị xóa (xóa mềm).
     * Chỉ người gửi gốc mới có thể đánh dấu xóa tin nhắn của họ.
     * @param _id ID của tin nhắn muốn đánh dấu xóa.
     */
    function markAsDeleted(uint _id) public {
        require(_id < messages.length, unicode"ID tin nhắn nằm ngoài giới hạn.");
        require(messages[_id].sender == msg.sender, unicode"Chỉ người gửi mới có thể xóa tin nhắn này.");
        require(!messages[_id].isDeleted, unicode"Tin nhắn đã được đánh dấu là đã xóa.");

        messages[_id].isDeleted = true;

        emit MessageDeleted(_id, msg.sender, block.timestamp);
    }

    /**
     * @dev Bật/tắt trạng thái thích (like) cho một tin nhắn.
     * Mỗi người dùng chỉ có thể thích một tin nhắn một lần.
     * @param _id ID của tin nhắn muốn thích/bỏ thích.
     */
    function toggleLike(uint _id) public {
        require(_id < messages.length, unicode"ID tin nhắn nằm ngoài giới hạn.");
        require(!messages[_id].isDeleted, unicode"Không thể thích/bỏ thích tin nhắn đã bị xóa.");

        if (userLikes[_id][msg.sender]) {
            // Người dùng đã thích, bây giờ bỏ thích
            userLikes[_id][msg.sender] = false;
            messages[_id].likesCount--;
            emit MessageUnliked(_id, msg.sender, block.timestamp);
        } else {
            // Người dùng chưa thích, bây giờ thích
            userLikes[_id][msg.sender] = true;
            messages[_id].likesCount++;
            emit MessageLiked(_id, msg.sender, block.timestamp);
        }
    }

    /**
     * @dev Lấy thông tin chi tiết của một tin nhắn dựa trên chỉ mục (index) của nó.
     * @param _index Chỉ mục của tin nhắn trong mảng `messages`.
     * @return message Trả về toàn bộ cấu trúc Message.
     */
    function getMessage(uint _index) public view returns (Message memory) {
        require(_index < messages.length, unicode"Chỉ mục nằm ngoài giới hạn.");
        return messages[_index];
    }

    /**
     * @dev Trả về tổng số tin nhắn hiện có trong hợp đồng (bao gồm cả đã xóa mềm).
     * @return Tổng số tin nhắn.
     */
    function getTotalMessages() public view returns (uint) {
        return messages.length;
    }

    /**
     * @dev Lấy tất cả các tin nhắn được gửi bởi một địa chỉ cụ thể.
     * Lưu ý: Việc lặp qua mảng lớn trên chuỗi có thể tốn gas.
     * Đối với ứng dụng thực tế, nên lọc ở backend bằng cách lắng nghe các sự kiện.
     * @param _sender Địa chỉ của người gửi.
     * @return Một mảng các đối tượng Message được gửi bởi `_sender`.
     */
    function getMessagesBySender(address _sender) public view returns (Message[] memory) {
        uint messageCount = messages.length;
        uint senderMessageCount = 0;

        // Đếm số lượng tin nhắn từ người gửi này
        for (uint i = 0; i < messageCount; i++) {
            if (messages[i].sender == _sender) {
                senderMessageCount++;
            }
        }

        // Tạo mảng động với kích thước chính xác
        Message[] memory senderMessages = new Message[](senderMessageCount);
        uint currentIndex = 0;

        // Điền các tin nhắn vào mảng mới
        for (uint i = 0; i < messageCount; i++) {
            if (messages[i].sender == _sender) {
                senderMessages[currentIndex] = messages[i];
                currentIndex++;
            }
        }
        return senderMessages;
    }

    /**
     * @dev Kiểm tra xem một người dùng cụ thể đã thích một tin nhắn cụ thể hay chưa.
     * @param _id ID của tin nhắn.
     * @param _user Địa chỉ của người dùng.
     * @return True nếu người dùng đã thích tin nhắn, ngược lại là False.
     */
    function getLikeStatus(uint _id, address _user) public view returns (bool) {
        require(_id < messages.length, unicode"ID tin nhắn nằm ngoài giới hạn.");
        return userLikes[_id][_user];
    }
}
