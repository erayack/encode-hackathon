%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC1155_Receiver:
    func onERC1155Received(
        operator: felt,
        from_: felt,
        token_id: felt,
        amount: felt,
        data_len: felt,
        data: felt*
    ) -> (selector: felt): 
    end

    func onERC1155BatchReceived(
        operator: felt,
        from_: felt,
        token_ids_len: felt,
        token_ids: felt*,
        amounts_len: felt,
        amounts: felt*,
        data_len: felt,
        data: felt*
    ) -> (selector: felt): 
    end
end