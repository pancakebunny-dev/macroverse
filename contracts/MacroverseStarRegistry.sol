pragma solidity ^0.4.11;

import "./MRVToken.sol";
import "./zeppelin/ownership/Ownable.sol";
import "./zeppelin/ownership/HasNoEther.sol";

/**
 * The Macroverse Star Registry keeps track of who currently owns virtual real estate in the
 * Macroverse world, at the scale of star systems and other star-like objects.
 *
 * Ownership is handled by having the first person who wants to own an object claim it, by
 * putting up a deposit in MRV tokens of a certain minimum size. Note that the owner of the
 * contract reserves the right to adjust this minimum size at any time, for any reason, and
 * without notice. Since the size of the deposit to be made is specified by the claimant,
 * trying to claim something when the minimum deposit size has been increased without your
 * knowledge should at worst result in wasted gas.
 *
 * Owners of objects can send them to other addresses, and an owner can abdicate ownership of
 * an object and collect the original MRV deposit used to claim it.
 *
 * Note that the claiming system used here is not protected against front-running. Anyone can
 * see your claim transaction before it is mined, and claim the object you were going for first.
 * However, they would then need to find it among the many billions of objects in the Macroverse
 * universe, because this contract only records ownership by seed.
 *
 * Note that ownership of a star system does not necessarily imply ownership of everything in it.
 * Just as one person can own a condo in another person's building, one person can own a planet in
 * another person's star system.
 *
 * All ownership is recorded using star seeds; no attempt is made to enforce that a given
 * seed actually exists in the Macroverse world. It is possible to purchase (and sell!)
 * nonexistent star systems, or star systems that you don't know where they are. Caveat emptor.
 *
 * The deployer of this contract reserves the right to supersede it with a new version at any time,
 * for any reason, and without notice. The deployer of this contract reserves the right to leave it
 * in place as is indefinitely.
 */
contract MacroverseStarRegistry is Ownable {
    
    // This is the token in which star ownership deposits have to be paid.
    MRVToken public tokenAddress;
    // This is the minimum ownership deposit in atomic token units.
    uint public minDepositInAtomicUnits;
    
    // This maps from star or other body seed to the address that owns it.
    // This can be queried without meeting the access control requirements.
    mapping(bytes32 => address) public ownerOf;
    
    // This holds what deposit was paid for each owned item.
    mapping(bytes32 => uint) public depositFor;
    
    // This event is fired when ownership of a star system. Giving up ownership transfers to the 0 address.
    event StarOwnershipChanged(bytes32 indexed starSeed, address indexed newOwner);
    
    /**
     * Deploy a new copy of the Macroverse Star Registry.
     * The given token will be used to pay deposits, and the given minimum
     * deposit size will be required.
     */
    function MacroverseRegistry(address depositTokenAddress, uint initialMinDepositInAtomicUnits) {
        // We can only use one token for the lifetime of the contract.
        tokenAddress = MRVToken(depositTokenAddress);
        // But the minimum deposit for new claims can change
        minDepositInAtomicUnits = initialMinDepositInAtomicUnits;
    }
    
    /**
     * Allow the owner to set the minimum deposit amount for granting new
     * ownership claims.
     */
    function setMinimumDeposit(uint newMinimumDepositInAtomicUnits) onlyOwner {
        minDepositInAtomicUnits = newMinimumDepositInAtomicUnits;
    }
    
    /**
     * Acquire ownership of an unclaimed star.
     * To claim a star, you need to put up a deposit of MRV. You need to call
     * approve() on the MRV token contract to allow this contract to debit the
     * requested deposit from your account. The deposit must be more than the
     * current minimum deposit.
     *
     * YOU and ONLY YOU are responsible for remembering the seeds of stars you
     * own, so you can get your deposits back when you are done with them.
     */
    function claimOwnership(bytes32 starSeed, uint depositInAtomicUnits) {
        // You can't claim things that are already owned.
        if (ownerOf[starSeed] != 0) throw;
        
        // You can claim things that don't exist, if you really want to.
        
        // You have to put up at least the minimum deposit
        if (depositInAtomicUnits < minDepositInAtomicUnits) throw;
        
        // Go ahead and do the state changes
        ownerOf[starSeed] = msg.sender;
        depositFor[starSeed] = depositInAtomicUnits;
        
        // After state changes, try to take the money
        tokenAddress.transferFrom(msg.sender, this, depositInAtomicUnits);
        // The MRV token will throw if transferFrom fails.
    }
    
    /**
     * Transfer ownership of a star from the sender to the given address.
     * You don't need to meet the access control requirements to get rid of
     * your owned stars, or to own stars. But you might not be able to
     * query anything about them.
     */
    function transferOwnership(bytes32 starSeed, address newOwner) {
        // You can't send things you don't own.
        if (ownerOf[starSeed] != msg.sender) throw;
        
        // Don't try to burn star ownership; use abdicateOwnership instead.
        if (newOwner == 0) throw;
        
        // Transfer owenership
        ownerOf[starSeed] = newOwner;
        
        // Announce it
        StarOwnershipChanged(starSeed, newOwner);
    }
    
    // In a future version, we might want an ERC20-style authorization system, to let a contract move your things for you.
    
    /**
     * Give up ownership of an owned star.
     * The MRV deposit originally paid to acquire ownership of the star will
     * be paid out to the sender of the message.
     */
    function abdicateOwnership(bytes32 starSeed) {
        // You can't give up things you don't own.
        if (ownerOf[starSeed] != msg.sender) throw;
        
        // How much should we return?
        var depositSize = depositFor[starSeed];
        
        // Clear ownership
        ownerOf[starSeed] = 0;
        // Clear the deposit value
        depositFor[starSeed] = 0;

        // Announce lack of ownership of the thing
        StarOwnershipChanged(starSeed, 0);
        
        // Pay back deposit
        tokenAddress.transfer(this, depositSize);
        // We know MRVToken throws on a failed transfer
    }
}