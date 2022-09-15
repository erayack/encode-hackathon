%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_check, uint256_eq
)

from starkware.starknet.common.syscalls import (get_contract_address, get_caller_address)

from openzeppelin.token.erc20.interfaces.IERC20 import IERC20

from openzeppelin.access.ownable import (
    Ownable_only_owner,
    Ownable_initializer,
    Ownable_owner
)

from contracts.token.ERC1155.ERC1155_Metadata_base import(
    ERC1155_Metadata_initializer, 
    ERC1155_Metadata_tokenURI, 
    ERC1155_Metadata_setBaseTokenURI 
)

@storage_var
func current_index() -> (token_id: Uint256):
end

@storage_var
func get_logic_contract() -> (logic_contract: felt):
end

@storage_var
func get_price() -> (price: Uint256):
end

@storage_var
func get_stETH_address() -> (stETH_address: felt):
end

@storage_var
func ERC1155_owners(token_id: Uint256) -> (owner_address: felt):
end

@event
func TransferSingle(operator: felt, from_: felt, to: felt, token_id: Uint256, value: felt):
end



@constructor
func constructor{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(owner: felt, stETH_address: felt, price: Uint256, base_token_uri_len: felt, base_token_uri: felt*, token_uri_suffix: felt):
    Ownable_initializer(owner)
    ERC1155_Metadata_initializer()
    ERC1155_Metadata_setBaseTokenURI(base_token_uri_len, base_token_uri, token_uri_suffix)
    get_stETH_address.write(value=stETH_address)
    get_price.write(value=price)
    return ()
end

@view
func ERC1155_ownerOf{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(token_id: Uint256) -> (owner: felt):
    alloc_locals
    let (owner) = ERC1155_owners.read(token_id=token_id)
    assert_not_zero(owner)
    return (owner)
end

@view
func tokenURI{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(token_id: Uint256) -> (token_uri_len: felt, token_uri: felt*):
    let (token_uri_len, token_uri) = ERC1155_Metadata_tokenURI(token_id)
    return (token_uri_len=token_uri_len, token_uri=token_uri)
end


@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(price: Uint256):
    alloc_locals
    let (stETH_address) = get_stETH_address.read()
    let (creator) = get_caller_address()
    let (contract) = get_contract_address()
    let (logic_contract) = get_logic_contract.read()
    let (price) =  get_price.read()
    is_artist_allowed(creator)
    IERC20.transferFrom(contract_address=stETH_address, sender=creator, recipient=contract, amount=price)
    let (success) = IERC20.transfer(contract_address=stETH_address, recipient=logic_contract,amount=price)
    assert success = 1
    let token_id : Uint256 = current_index.read()
    let one_as_uint = Uint256(1,0)
    let (new_token_id, _) = uint256_add(one_as_uint, token_id)
    ERC1155_owners.write(token_id=token_id, value=creator)
    TransferSingle.emit(operator=creator, from_=0,to=creator, token_id=token_id, value=1)
    current_index.write(value = new_token_id)
    return()
end 

@external
func set_logic_contract{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(logic_contract: felt):
    Ownable_only_owner()
    assert_not_zero(logic_contract)
    get_logic_contract.write(value=logic_contract) 
    return() 
end

#internal functions

func is_artist_allowed{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(artist: felt):
	alloc_locals
	let (stETH_address) = get_stETH_address.read()
    let (contract) = get_contract_address()
    let (price) = get_price.read()
	let allowance : Uint256 = IERC20.allowance(contract_address=stETH_address,owner=artist,spender=contract)
    let (is_allowance_enough) = uint256_lt(price, allowance)
    with_attr error_message("please increase allowance"):
        assert is_allowance_enough = 1
    end
	return()
end