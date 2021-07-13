pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';

contract Ownable is AccessControl {
    bytes32 public constant admin = keccak256("admin_");
    bytes32 public constant creator = keccak256("creator_");

    constructor() {
        _setupRole(admin, _msgSender());
        _setupRole(creator, _msgSender());
    }
}

contract DealChain is Ownable, ERC20 {
    constructor() ERC20("DealChain", "DCN") {}

    function mint(address to, uint amount) public virtual {
        require(hasRole(creator, _msgSender()), "Must have minter role");
        _mint(to, amount);
    }
}

contract Deal is ERC721 {

    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenId;
    ERC20 private _currency;

    event userRegistered(address indexed user, uint timestamp, uint id);
    event issuerRegistered(address indexed issuer);
    event offerCreated(address indexed issuer, uint tokenID, uint timestamp, string description, uint amount);
    event offerRevoked(address indexed issuer, uint tokenID, string description);

    mapping(address => bool) issuers;
    mapping(address => uint) users;

    struct offer {
        address issuer;
        uint id;
        uint timestamp;
        uint expireDate;
        uint amount;
        uint priceInDCN;
        string description;
    }

    mapping(address => mapping(uint => uint)) internal holders;
    mapping (uint => offer) internal offers;
    uint[] public offerList;

    constructor() ERC721("DealChainCoupon", "DCNC") public {
        _tokenId.increment();
    }
    
    modifier onlyRegisteredIssuers {
        require(issuers[msg.sender], "You must be an Issuer");
        _;
    }
    
    function registerIssuer(address _issuer) public {
        emit issuerRegistered(_issuer);
        issuers[_issuer] = true;
    }

    modifier onlyRegisteredUsers {
        require(users[msg.sender] > 0, "Only Users");
        _;
    }

    function registerPPABuyer(address _user) public {
        uint _userID = 0;
        uint _timestamp = block.timestamp;
        _userID++;
        if(_userID != 0) {
            emit userRegistered(_user, _timestamp, _userID);
        }
        users[_user] = _userID;
    }

    function createOffer(offer memory _offer, string memory _description, uint _amount) public onlyRegisteredIssuers virtual returns(uint){
        uint currentID = _tokenId.current();
        _offer.id = currentID;
        _offer.issuer = msg.sender;
        _offer.description = _description;
        _offer.amount = _amount;

        _safeMint(msg.sender, currentID);
        _tokenId.increment();

        offers[currentID] = _offer;
        offerList.push(currentID);

        return currentID;
    }

    function purchaseOffer(uint offerID) external payable {
        offer storage _offer = offers[offerID];
        uint _amount = 1;
        require(_offer.id > 0, "Non existence offer");
        require(_offer.amount > 0, "Out of stock");
        require(_amount > _offer.amount, "Not enough offers");
        require(_currency.balanceOf(msg.sender) >= _amount.mul(_offer.priceInDCN), "Do not have enough DCN Tokens");

        //transfer DCN to beneficiary address
        _currency.transfer(msg.sender, _amount.mul(_offer.priceInDCN));
        _offer.amount -= _amount;
        
        //add amount to buyer
        holders[msg.sender][offerID] += _amount;
    }
}