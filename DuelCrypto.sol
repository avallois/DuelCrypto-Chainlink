pragma solidity ^0.8.0;

import "./VRFConsumerBase.sol";

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMathTryMul {
    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }
}

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// pragma solidity ^0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

/**
 * @title DuelCrypto
 */
contract DuelCrypto is VRFConsumerBase, Ownable, ReentrancyGuard {
    using SafeMathTryMul for uint256;

    uint256 public lastDuelId;
    uint256 public minBet;

    uint256 public feeOnWinnings = 1; // 1%, transfer calculation logic results in less than 1% fee

    bytes32 private rgKeyHash;
    uint256 private rgFee;

    enum Status {
        Pending,
        Canceled,
        Launched,
        Claimable,
        Closed
    }

    struct Duel {
        Status status;
        address player1;//initiator
        address player2;
        uint256 bet;
        uint16 winner;//0: no winner, 1: player1 , 2: player2
    }

    mapping(address => uint256[]) private duelIds;//duelIds by player
    mapping(uint256 => Duel) private duels;//duels by duelIds
    mapping(bytes32 => uint256) private requestIdDuelId;//duelId by requestId for random number generator

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    constructor(address vrfCoordinator, address link, bytes32 keyHash, uint256 fee)
        VRFConsumerBase(vrfCoordinator, link) {
            rgKeyHash = keyHash;
            rgFee = fee;
    }

    event DuelCreated(uint256 duelId, address creator, uint256 bet);
    event DuelCanceled(uint256 indexed duelId, address indexed player1, uint256 bet);
    event DuelLaunched(uint256 indexed duelId, address indexed player1, address indexed player2, uint256 bet, uint16 winner);
    event DuelWinnerEstablished(uint256 indexed duelId, address indexed player1, address indexed player2, uint256 winner);
    event DuelRewardClaimed(uint256 indexed duelId, address indexed player, uint256 winnings);

    function createDuel() external payable notContract nonReentrant {
        require(msg.value >= minBet, "Bet lower than minBet");
        (bool isBetValid, ) = (msg.value).tryMul(200); 
        require(isBetValid == true, "Bet too high");
        lastDuelId++;
        duelIds[msg.sender].push(lastDuelId);
        duels[lastDuelId] = Duel(
            Status.Pending,
            msg.sender,
            address(0),
            msg.value,
            0
        );

        emit DuelCreated(lastDuelId, msg.sender, msg.value);
    }

    function startDuel(uint256 _duelId) external payable notContract nonReentrant {
        require(msg.sender != duels[_duelId].player1, "Player play against himself");
        require(msg.value == duels[_duelId].bet, "Invalid paid amount");
        require(duels[_duelId].status == Status.Pending, "Invalid duel status");
        //checking SC LINK balance for Random Generator
        require(LINK.balanceOf(address(this)) >= rgFee, "Not enough LINK to pay fee");

        duelIds[msg.sender].push(_duelId);
        duels[_duelId].player2 = msg.sender;

        requestIdDuelId[requestRandomness(rgKeyHash, rgFee)] = _duelId;

        // duels[_duelId].winner = (randomNumber % 2 == 0) ? 1 : 2;//cet ligne est a remettre au moment de la reception du random number
        //apres avoir demandé le numéro random il faut qu'on enregistre le request id en mode mapping ID => duelId
        duels[_duelId].status = Status.Launched;
        // Dans la fonction de reception on fera le tirage et on passera le duel en status claimable

        emit DuelLaunched(_duelId, duels[_duelId].player1, msg.sender, msg.value, duels[_duelId].winner);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        setWinner(requestId, randomness);
    }

    function setWinner(bytes32 _requestId, uint256 _randomness) private {
        require(duels[requestIdDuelId[_requestId]].status == Status.Launched, "Invalid duel status");
        require(duels[requestIdDuelId[_requestId]].winner == 0, "winner already set");

        duels[requestIdDuelId[_requestId]].winner = (_randomness % 2 == 0) ? 1 : 2;
        duels[requestIdDuelId[_requestId]].status = Status.Claimable;
 
        emit DuelWinnerEstablished(
            requestIdDuelId[_requestId],
            duels[requestIdDuelId[_requestId]].player1,
            duels[requestIdDuelId[_requestId]].player2,
            duels[requestIdDuelId[_requestId]].winner
        );
    }

    function cancelDuelandRefund(uint256 _duelId) external notContract nonReentrant {
        require(duels[_duelId].status == Status.Pending, "Invalid duel status");
        require(msg.sender == duels[_duelId].player1, "Not called by duel owner");

        duels[_duelId].status = Status.Canceled;
        payable(msg.sender).transfer(duels[_duelId].bet);

        emit DuelCanceled(_duelId, msg.sender, duels[_duelId].bet);
    }

    function claimReward(uint256 _duelId) external notContract nonReentrant {
        require(duels[_duelId].status == Status.Claimable, "Invalid duel status");
        require(
            (msg.sender == duels[_duelId].player1 && duels[_duelId].winner == 1)
            || (msg.sender == duels[_duelId].player2 && duels[_duelId].winner == 2),
            "Claimer is not the winner"
        );

        duels[_duelId].status = Status.Closed;

        payable(msg.sender).transfer(
            ((duels[_duelId].bet * 2 * (100 - feeOnWinnings)) / 100) + 1
        );//transfer taxedWinnings

        payable(owner()).transfer(
            duels[_duelId].bet * 2 - (((duels[_duelId].bet * 2 * (100 - feeOnWinnings)) / 100) + 1)
        );//transfer fees to owner

        emit DuelRewardClaimed(_duelId, msg.sender, ((duels[_duelId].bet * 2 * (100 - feeOnWinnings)) / 100) + 1);
    }

    //function called by chainlink coordinator to return the generated random number 

    /**
     * @notice Returns true if `account` is a contract.
     * @param account: account address
     */
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

}

//voir si la taxe que l'on prend est pertinente par rapport au coût de chainlink ou voir si on peut pas reduire les coûts
//          eventuellement voir si on ne calculerait pas la fees en fonction du prix du LINK par rapport
//ou bien voir si on ne le fait pas sur MATIC
//faire le fonction view