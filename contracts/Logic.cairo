%lang starknet
%builtins pedersen range_check


from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_check, uint256_eq
)

from starkware.starknet.common.syscalls import (get_contract_address, get_caller_address, get_block_number)

from openzeppelin.token.erc20.interfaces.IERC20 import IERC20

from openzeppelin.access.ownable import (
    Ownable_only_owner,
    Ownable_initializer,
    Ownable_owner
)

from contracts.interfaces.IERC1155 import IERC1155


@storage_var
func user_list(address: felt) -> (is_user: felt):
end

@storage_var
func get_expiry_time() -> (expiry_time: felt):
end

@storage_var
func get_royalties_price() -> (price: felt):
end

@storage_var
func get_songs_contract() -> (songs_contract: felt):
end

@storage_var
func get_stETH_address() -> (stETH_address: felt):
end

@storage_var
func get_subscription_price() -> (price: felt):
end

@storage_var
func get_user_expiry_time(address: felt) -> (user_expiry_time: felt):
end

@constructor
func constructor{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(owner: felt, stETH_address: felt, songs_contract: felt, price: felt):
    Ownable_initializer(owner)
    get_stETH_address.write(value=stETH_address)
    get_songs_contract.write(value=songs_contract)
    get_subscription_price.write(value=price)
    return ()
end

@view
func is_subscribed{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(address: felt) -> (valid: felt):
    alloc_locals
    let (valid_user) = user_list.read(address=address)
    let (block_number) = get_block_number()
    let (user_expiry_time) = get_user_expiry_time.read(address=address)
    let (still_subscribed) = is_le(user_expiry_time, block_number)
    let valid = valid_user * still_subscribed
    return (valid)
end

@external
func sign_up{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals
	let (stETH_address) = get_stETH_address.read()
    let (caller) = get_caller_address()
    let (contract) = get_contract_address()
    let (block_number) = get_block_number()
    let (expiry_time) = get_expiry_time.read()
    is_user_allowed(caller)
    let (price) = get_subscription_price.read()
    IERC20.transferFrom(contract_address=stETH_address, sender=caller, recipient=contract, amount=Uint256(price,0))
    user_list.write(address=caller, value=1)
    get_user_expiry_time.write(address=caller, value=block_number+ expiry_time)
    return()
end

# in JS, try to get tx receipt, and re-send if error
# maybe prevent playing if contract does not have enough funds?
@external
func play{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(token_id: Uint256) -> ():
    alloc_locals
    let (contract) = get_contract_address()
    let (songs_contract) = get_songs_contract.read()
    let (artist) = IERC1155.ERC1155_ownerOf(contract_address=songs_contract, token_id=token_id)
    let (stETH_address) = get_stETH_address.read()
    with_attr error_message("this song number does not correspond to any song"):
        assert_not_zero(artist)
    end
    let (payment) = get_royalties_price.read()
    let (balance) = IERC20.balanceOf(contract_address=stETH_address, account=contract)
    with_attr error_message("the contract does not have enough funds"):
        let (is_enough) = uint256_le(Uint256(payment,0), balance)
        assert is_enough = 1
    end
    IERC20.transfer(contract_address=stETH_address, recipient=artist,amount=Uint256(payment,0))
    return()
end

# add Ownable modifier
@external
func set_songs_contract{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(songs_contract: felt):
    Ownable_only_owner()
    assert_not_zero(songs_contract)
    get_songs_contract.write(value=songs_contract)  
    return()
end

@external
func set_royalties_price{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(royalties_price: felt):
    Ownable_only_owner()
    assert_not_zero(royalties_price)
    get_royalties_price.write(value=royalties_price) 
    return() 
end

#internal functions

func is_user_allowed{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(user: felt):
    alloc_locals
	let (stETH_address) = get_stETH_address.read()
    let (contract) = get_contract_address()
    let (price) = get_royalties_price.read()
    let price_uint : Uint256 = Uint256(price,0)
	let (allowance) = IERC20.allowance(contract_address=stETH_address,owner=user,spender=contract)
    with_attr error_message("please increase allowance"):
        let (is_allowance_enough) = uint256_lt(price_uint, allowance)
        assert is_allowance_enough = 1   
    end
	return()
end
