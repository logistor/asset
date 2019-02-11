pragma solidity 0.4.24;

// ----------------------------------------------------------------------------
// General asset contract.
// Copyright logistor.
// MIT Licenced.
// ----------------------------------------------------------------------------

import "./Owned.sol";

contract Asset is Owned() {

    // Event of burn request
    event Request(address issuer, bytes32 id);
    // Event of accepted burn request
    event Accept(address owner, bytes32 id);
    // Event of succesfull burning
    event Burn(address issuer, bytes32 id);

    struct Item {
        bytes32 id;
        address issuer;
        bytes32 name;
        uint64 value;
        bytes32 unit;
        uint64 qty;
        uint64 validity;        // Last valid date in milliseconds.
        bool resale;
        uint256 ndex;           // To prevent looping
    }

    //** Mappings for holdings. **//
    // Holdings are visible to public but modifiable only by this contract.
    // 1st key - address of the owner
    // 2nd key - item id. 
    mapping(address => mapping(bytes32 => Item)) private holdings;
    // Helper for holdings.
    mapping(address => bytes32[]) private indexes;
    
    //** Assets that are for sale. **//
    // 1st key - address of the owner
    // 2nd key - item id
    // 2nd value - price.
    mapping(address => mapping(bytes32 => uint64)) private forsale;

    //** Reqests for burning item. **//
    // 1st key - address of the owner
    // 2nd key - item id
    // 2nd value - address of request sender
    mapping(address => mapping(bytes32 => address)) private requests;
    
    //** Item accepted for burning. **//
    // 1st key - address of the issuer
    // 2nd key - item id
    // 2nd value - address of the owner.
    mapping(address => mapping(bytes32 => address)) private accepted;
    
    function issue(bytes32 name, uint64 value, bytes32 unit, uint64 qty, uint64 validity, bool resale) public {
        require(validity > now);
        
        bytes32 id = keccak256(abi.encodePacked(name, msg.sender));
        uint256 len = indexes[msg.sender].length;

        Item memory i = Item(id, msg.sender, name, value, unit, qty, validity, resale, len); 
        holdings[msg.sender][id] = i;
        indexes[msg.sender].push(id);
    }

    function length() public view returns (uint256 len) {
        return indexes[msg.sender].length;
    }

    function get(uint256 index) public view returns(bytes32 id, address issuer, bytes32 name, uint64 value, bytes32 unit, uint64 qty, uint64 validity, bool resale, bool isforsale, uint256 ndex) {

        id = indexes[msg.sender][index];
        require(id != 0, "Index out of bounds.");

        Item memory item = holdings[msg.sender][id];

        isforsale = false;
        if (forsale[msg.sender][id] > 0){
            isforsale = true;
        }
        
        return (item.id, item.issuer, item.name, item.value, item.unit, item.qty, item.validity, item.resale, isforsale, item.ndex);
    }

    function sell(bytes32 id, uint64 price) public returns (bool) {
        
        Item memory item = holdings[msg.sender][id];
        require(item.id != 0, "No asset found for selling.");

        // If asset is not for resale only the issuer can sell it.
        if (!item.resale) {
            require(item.issuer == msg.sender);
        }

        // Check for validity
        require(item.validity >= now);

        // Check resale price
        //require(item.resale <= price);

        forsale[msg.sender][id] = price;
        return true;
    }

    // All functions must succeed or everything should be rolled back.
    function buy(address owner, bytes32 id, uint64 qty) public payable {

        // Check that seller owns the asset and it exists
        Item storage asset = holdings[owner][id];
        require(asset.id != 0, "Asset does not exist.");

        // Check that asset is for sale
        uint64 price = forsale[owner][id];
        require(price != 0, "Asset is not for sale.");

        // Check that seller has required quantity
        require(asset.qty >= qty, "Required qty does not exist.");

        // Check that buyer has sent enough value
        require(msg.value >= price * qty, "Not enough value.");
        
        // Subtract the quantity of assets in account
        asset.qty -= qty;

        // If asset is used then reduce old owners helper array
        if (asset.qty == 0){
            pop(owner, asset);
        }

        // Check if the beneficiary already has some of the asset.
        Item storage existing = holdings[msg.sender][id];
        if (existing.qty > 0) {
            existing.qty += qty;
        } else {
            uint256 len = indexes[msg.sender].length;
            Item memory newAsset = Item(id, asset.issuer, asset.name, asset.value, asset.unit, qty, asset.validity, asset.resale, len);
            holdings[msg.sender][id] = newAsset;
            indexes[msg.sender].push(id);
        }

        // Pay the seller
        require(owner.send(msg.value));
    }

    // Request for burning an asset
    function request(address owner, bytes32 id) public returns (bool success) {
        Item memory asset = holdings[owner][id];
        
        require(asset.qty > 0, "No value left.");
        require(asset.issuer == msg.sender, "Only issuer can send burn requests.");
        
        requests[owner][id] = msg.sender;
        emit Request(owner, id);
        
        return true;
    }

    // Accept burning request
    function accept(bytes32 id) public returns (bool success) {

        address issuer = requests[msg.sender][id];
        accepted[issuer][id] = msg.sender;
        requests[msg.sender][id] = address(0);

        emit Accept(msg.sender, id);
        return true;
    }

    // Burn an asset
    function burn(bytes32 id) public returns (bool success) {

        address owner = accepted[msg.sender][id];
        require(owner != address(0), "Asset is not accepted for burning.");

        Item storage asset = holdings[owner][id];
        require(asset.issuer == msg.sender, "Only issuer is allowed to burn asset.");
        
        asset.qty--;
        accepted[msg.sender][id] = address(0);

        // If asset is used then reduce owners helper array
        if (asset.qty == 0){
            pop(owner, asset);
        }

        emit Burn(msg.sender, asset.id);
        return true;
    }

    function pop(address owner, Item asset) private {

        bytes32[] storage array = indexes[owner];
        uint256 ndex = array.length - 1;
            
        // If asset is not the last one.
        if (asset.ndex < ndex){
            bytes32 lastId = array[ndex];
            Item storage lastItem = holdings[owner][lastId];
            lastItem.ndex = asset.ndex;
            array[asset.ndex] = lastId;
        }

        indexes[owner].length = ndex;  // This can be changed to pop() from Solidity 0.5.5 onwards.
    }

}