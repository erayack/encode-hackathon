%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC1155:
    func ERC1155_ownerOf(token_id: Uint256) -> (owner: felt):
    end
end