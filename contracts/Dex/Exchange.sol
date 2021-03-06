// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Token.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

/**./
 * @title Exchange
 * @author Tyler Cranmer
 *
 * Small Decentralized Exchange where you can swap tokens and make trades.
 */
contract Exchange {
    using SafeMath for uint256;

    /* ============ State Variables ============ */

    // Exchange fee percentage and address that recieves exchange fee.
    address public feeAccount;
    uint256 public feePercent;

    // assign the 0 address to ether, to store ether amount
    // in mapping for minimizing storage on the blockchain
    address public constant ETHER = address(0);

    // counter to record the orders made.
    uint256 public orderCount;

    // 1st key: token address, 2nd key: deposit user address, value: number of tokens
    mapping(address => mapping(address => uint256)) public tokens;
    mapping(uint256 => _Order) public orders;
    mapping(uint256 => bool) public orderCancelled;
    mapping(uint256 => bool) public orderFilled;

    event Deposit(address token, address user, uint256 amount, uint256 balance);
    event Withdraw(
        address token,
        address user,
        uint256 amount,
        uint256 balance
    );
    event Order(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint256 timestamp
    );
    event Cancel(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint256 timestamp
    );
    event Trade(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint256 timestamp
    );

    /* ============ Struct ============ */

    /**
     * Struct containing information for Orders
     */
    struct _Order {
        uint256 id;
        address user;
        address tokenGet;
        uint256 amountGet;
        address tokenGive;
        uint256 amountGive;
        uint256 timestamp;
    }

    /* ============ Constructor ============ */

    /**
     * Set state variables
     *
     * @param _feeAccount   Address of the account that hold the fees
     * @param _feePercent  uint256 of fee percentage
     *
     */

    constructor(address _feeAccount, uint256 _feePercent) {
        require(_feeAccount != address(0));
        feeAccount = _feeAccount;
        feePercent = _feePercent;
    }

    receive() external payable {
        revert("Use Deposit Ether Function");
    }

    /**
     * Deposits Ether into users token account with a mapping to the ETHER address.
     *
     * event Deposit
     *
     */
    function depositEther() public payable {
        tokens[ETHER][msg.sender] = tokens[ETHER][msg.sender].add(msg.value);
        emit Deposit(ETHER, msg.sender, msg.value, tokens[ETHER][msg.sender]);
    }

    /**
     * Withdraws Ether from users ether account
     *
     * @param _amount amount of ether user would like to withdraw.
     * event Withdraw
     *
     */
    function withdrawEther(uint256 _amount) public {
        require(tokens[ETHER][msg.sender] >= _amount, "Not enough tokens");
        tokens[ETHER][msg.sender] = tokens[ETHER][msg.sender].sub(_amount);
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Transfer failed");
        emit Withdraw(ETHER, msg.sender, _amount, tokens[ETHER][msg.sender]);
    }

    /**
     * ERC20 Deposit token
     *
     * @param _token token address
     * @param _amount token amount the user would like to deposit.
     * event Deposit
     *
     */
    function depositToken(address _token, uint256 _amount) public {
        //Shouldnt take in ETHER
        require(_token != ETHER);
        require(Token(_token).transferFrom(msg.sender, address(this), _amount));

        //deposit token amount into mapping
        tokens[_token][msg.sender] = tokens[_token][msg.sender].add(_amount);
        emit Deposit(_token, msg.sender, _amount, tokens[_token][msg.sender]);
    }

    /**
     * ERC20 withdraw tokens
     *
     * @param _token token address
     * @param _amount token amount the user would like to withdraw.
     * event Deposit
     *
     */
    function withdrawToken(address _token, uint256 _amount) public {
        require(_token != ETHER, "cannot withdraw ETHER");
        require(tokens[_token][msg.sender] >= _amount, "Not enough funds");
        tokens[_token][msg.sender] = tokens[_token][msg.sender].sub(_amount);
        require(Token(_token).transfer(msg.sender, _amount));

        emit Withdraw(_token, msg.sender, _amount, tokens[_token][msg.sender]);
    }

    /**
     * Function to get the owners blance of particular token
     *
     * @param _token token address
     * @param _owner owner address for token
     * @return balance
     *
     */
    function balanceOf(address _token, address _owner)
        public
        view
        returns (uint256 balance)
    {
        balance = tokens[_token][_owner];
        return balance;
    }

    /**
     * Generates an order of a trade to be fullfilled.
     *
     * @param _tokenGet Address of token the user is trying to swap for.
     * @param _amountGet Amount of tokens looking to swap for.
     * @param _tokenGive Address of the tokens the user is swaping with.
     * @param _amountGive Amount of tokens looking to swap with.
     * event Deposit
     *
     */
    function makeOrder(
        address _tokenGet,
        uint256 _amountGet,
        address _tokenGive,
        uint256 _amountGive
    ) public {
        orderCount = orderCount.add(1);
        orders[orderCount] = _Order(
            orderCount,
            msg.sender,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            block.timestamp
        );

        emit Order(
            orderCount,
            msg.sender,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            block.timestamp
        );
    }

    /**
     * Cancels an order of a trade to be fullfilled.
     *
     * @param _id Order id for orders mapping
     *
     * event Cancel
     *
     */
    function cancelOrder(uint256 _id) public {
        _Order storage order = orders[_id];
        require(
            address(order.user) == msg.sender,
            "Only the owner can cancel the order."
        );
        require(order.id == _id);
        orderCancelled[_id] = true;
        emit Cancel(
            order.id,
            msg.sender,
            order.tokenGet,
            order.amountGet,
            order.tokenGive,
            order.amountGive,
            block.timestamp
        );
    }

    /**
     * fillOrder an order that has been created.
     *
     * @param _id Order id for orders mapping
     *
     *
     */
    function fillOrder(uint256 _id) public {
        require(_id > 0 && _id <= orderCount, "Not a valid order");
        require(!orderFilled[_id], "Order has already been filled");
        require(!orderCancelled[_id], "Order has already been cancelled");

        _Order storage order = orders[_id];
        _trade(
            _id,
            order.user,
            order.tokenGet,
            order.amountGet,
            order.tokenGive,
            order.amountGive
        );
        orderFilled[order.id] = true;
    }

    /**
     * Internal trade function for fillOrder
     *
     * @param _orderId order id
     * @param _user address of user who made order
     * @param _tokenGet address of token to trade for
     * @param _amountGet The token amount that the user will receive
     * @param _tokenGive address of token to trade with
     * @param _amountGive The token amount that the user will trade with
     *
     * event Cancel
     *
     */
    function _trade(
        uint256 _orderId,
        address _user,
        address _tokenGet,
        uint256 _amountGet,
        address _tokenGive,
        uint256 _amountGive
    ) internal {
        uint256 _feeAmount = _amountGet.mul(feePercent).div(100);

        // Execute trade
        // Get sender balance and substract amount Get
        tokens[_tokenGet][msg.sender] = tokens[_tokenGet][msg.sender].sub(
            _amountGet
        );

        // Get the user balance and add the previous value minus fee
        tokens[_tokenGet][_user] = tokens[_tokenGet][_user].add(
            _amountGet.sub(_feeAmount)
        );

        // add fee to feeAccount
        tokens[_tokenGet][feeAccount] = tokens[_tokenGet][feeAccount].add(
            _feeAmount
        );

        // get user balance and subtract the amount get
        tokens[_tokenGive][_user] = tokens[_tokenGive][_user].sub(_amountGive);

        //get the sender balance and add the previous value;
        tokens[_tokenGive][msg.sender] = tokens[_tokenGive][msg.sender].add(
            _amountGive
        );

        emit Trade(
            _orderId,
            _user,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            block.timestamp
        );
    }
}
