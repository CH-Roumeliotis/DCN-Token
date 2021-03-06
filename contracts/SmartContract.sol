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

    function mint(address to, uint256 amount) public virtual {
        require(hasRole(creator, _msgSender()), "Must have minter role");
        _mint(to, amount);
    }
}

contract Deal is ERC721 {

    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenId;
    ERC20 private _currency;

    event userRegistered(address indexed user, uint256 timestamp, uint256 id);
    event issuerRegistered(address indexed issuer);
    event offerCreated(address indexed issuer, uint256 tokenID, uint256 timestamp, string description, uint256 amount);
    event offerRevoked(address indexed issuer, uint256 tokenID, string description);

    mapping(address => bool) issuers;
    mapping(address => uint256) users;

    struct offer {
        address issuer;
        uint256 id;
        uint256 timestamp;
        uint256 expireDate;
        uint256 amount;
        uint256 priceInDCN;
        string description;
    }

    mapping(address => mapping(uint256 => uint256)) internal holders;
    mapping (uint256 => offer) internal offers;
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

    function registerUser(address _user) public {
        uint256 _userID = 0;
        uint256 _timestamp = block.timestamp;
        _userID++;
        if(_userID != 0) {
            emit userRegistered(_user, _timestamp, _userID);
        }
        users[_user] = _userID;
    }

    function createOffer(offer memory _offer) public onlyRegisteredIssuers virtual returns(uint256){
        uint256 currentID = _tokenId.current();
        _offer.id = currentID;
        _offer.issuer = msg.sender;

        _safeMint(msg.sender, currentID);
        _tokenId.increment();

        offers[currentID] = _offer;
        offerList.push(currentID);

        return currentID;
    }

    function purchaseOffer(uint256 offerID) external payable {
        offer storage _offer = offers[offerID];
        uint256 _amount = 1;
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