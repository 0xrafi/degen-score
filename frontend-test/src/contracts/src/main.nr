use dep::aztec::macros::aztec;

#[aztec]
contract DegenScore {
    use dep::aztec::{
        prelude::{AztecAddress, PrivateMutable, Map, NoteInterface},
        encrypted_logs::encrypted_note_emission::encode_and_encrypt_note_with_keys,
        macros::{storage::storage, functions::{private, public, initializer}}
    };
    use dep::value_note::value_note::ValueNote;

    struct DegenData {
        trading_volume: Field,
        leverage_score: Field,
        yield_farming_score: Field,
        nft_score: Field,
        risk_score: Field,
        token_diversity: Field,
    }

    #[storage]
    struct Storage<Context> {
        degen_scores: Map<AztecAddress, PrivateMutable<ValueNote, Context>, Context>,
    }

    #[private]
    #[initializer]
    fn constructor(owner: AztecAddress) {
        let degen_scores = storage.degen_scores;
        let initial_score = 0;
        let mut initial_note = ValueNote::new(initial_score, owner.to_field());
        degen_scores.at(owner).initialize(&mut initial_note);
    }

    #[private]
    fn update_degen_score(
        user: AztecAddress,
        eth_signature: [Field; 65],
        trading_volume: Field,
        leverage_score: Field,
        yield_farming_score: Field,
        nft_score: Field,
        risk_score: Field,
        token_diversity: Field
    ) {
        // In a real implementation, we would verify the Ethereum signature here
        // For this PoC, we'll assume the signature is valid

        let degen_scores = storage.degen_scores;
        let updated_data = DegenData {
            trading_volume,
            leverage_score,
            yield_farming_score,
            nft_score,
            risk_score,
            token_diversity,
        };
        let new_score = calculate_degen_score(updated_data);
        let mut new_note = ValueNote::new(new_score, user.to_field());
        degen_scores.at(user).replace(&mut new_note);
    }

    fn calculate_degen_score(data: DegenData) -> pub Field {
        // Simplified scoring algorithm
        data.trading_volume / 1000 +
        data.leverage_score * 10 +
        data.yield_farming_score * 5 +
        data.nft_score * 2 +
        data.risk_score * 15 +
        data.token_diversity * 3
    }

    unconstrained fn get_degen_score(user: AztecAddress) -> pub ValueNote {
        let degen_scores = storage.degen_scores;
        degen_scores.at(user).view_note()
    }

    use dep::aztec::test::{helpers::{cheatcodes, test_environment::TestEnvironment}};
    use dep::aztec::protocol_types::storage::map::derive_storage_slot_in_map;
    use dep::aztec::note::note_getter::{MAX_NOTES_PER_PAGE, view_notes};
    use dep::aztec::note::note_viewer_options::NoteViewerOptions;

    #[test]
    unconstrained fn test_constructor_initializes_score() {
        let mut env = TestEnvironment::new();
        let owner = env.create_account();
        env.impersonate(owner);

        let initializer = DegenScore::interface().constructor(owner);
        let degen_score_contract = env.deploy_self("DegenScore").with_private_initializer(initializer);
        let contract_address = degen_score_contract.to_address();

        env.impersonate(contract_address);
        let unconstrained_context = env.unkonstrained();
        // have to setup unconstrained context, storage layout only works for public
        let storage = PrivateGroups::Storage::init(unconstrained_context);
        
        // commented out lines are for public
        // let degen_scores_slot = DegenScore::storage_layout().degen_scores.slot;
        // let owner_slot = derive_storage_slot_in_map(degen_scores_slot, owner);
        
        let mut options = NoteViewerOptions::new();
        let notes: BoundedVec<ValueNote, MAX_NOTES_PER_PAGE> = view_notes(owner_slot, options);
        degen_scores
        let initial_score = notes.get(0).value;

        assert(initial_score == 0, f"Expected initial score 0 but got {initial_score}");
    }

    #[test]
    unconstrained fn test_update_degen_score() {
        let mut env = TestEnvironment::new();
        let owner = env.create_account();
        let user = env.create_account();
        env.impersonate(owner);

        let initializer = DegenScore::interface().constructor(owner);
        let degen_score_contract = env.deploy_self("DegenScore").with_private_initializer(initializer);
        let contract_address = degen_score_contract.to_address();

        let eth_signature = [0; 65];
        let trading_volume = 1000;
        let leverage_score = 2;
        let yield_farming_score = 3;
        let nft_score = 1;
        let risk_score = 4;
        let token_diversity = 2;

        let update_score_interface = DegenScore::at(contract_address).update_degen_score(
            user,
            eth_signature,
            trading_volume,
            leverage_score,
            yield_farming_score,
            nft_score,
            risk_score,
            token_diversity,
        );
        env.call_private_void(update_score_interface);

        let expected_score = trading_volume / 1000 +
            leverage_score * 10 +
            yield_farming_score * 5 +
            nft_score * 2 +
            risk_score * 15 +
            token_diversity * 3;

        let current_score = DegenScore::at(contract_address).get_degen_score(user).simulate();
        assert(current_score.value == expected_score, f"Expected score {expected_score} but got {current_score.value}");
    }

    #[test]
    unconstrained fn test_multiple_updates() {
        let mut env = TestEnvironment::new();
        let owner = env.create_account();
        let user = env.create_account();
        env.impersonate(owner);

        let initializer = DegenScore::interface().constructor(owner);
        let degen_score_contract = env.deploy_self("DegenScore").with_private_initializer(initializer);
        let contract_address = degen_score_contract.to_address();

        let eth_signature = [0; 65];

        // First update
        let update_score_interface1 = DegenScore::at(contract_address).update_degen_score(
            user, eth_signature, 1000, 2, 3, 1, 4, 2
        );
        env.call_private_void(update_score_interface1);

        let score_after_first_update = DegenScore::at(contract_address).get_degen_score(user).simulate();

        // Second update
        let update_score_interface2 = DegenScore::at(contract_address).update_degen_score(
            user, eth_signature, 2000, 3, 4, 2, 5, 3
        );
        env.call_private_void(update_score_interface2);

        let score_after_second_update = DegenScore::at(contract_address).get_degen_score(user).simulate();

        assert(
            score_after_second_update.value > score_after_first_update.value,
            "Score should increase after second update"
        );
    }

    #[test]
    unconstrained fn test_multiple_users() {
        let mut env = TestEnvironment::new();
        let owner = env.create_account();
        let user1 = env.create_account();
        let user2 = env.create_account();
        env.impersonate(owner);

        let initializer = DegenScore::interface().constructor(owner);
        let degen_score_contract = env.deploy_self("DegenScore").with_private_initializer(initializer);
        let contract_address = degen_score_contract.to_address();

        let eth_signature = [0; 65];

        let update_score_interface1 = DegenScore::at(contract_address).update_degen_score(
            user1, eth_signature, 1000, 2, 3, 1, 4, 2
        );
        env.call_private_void(update_score_interface1);

        let update_score_interface2 = DegenScore::at(contract_address).update_degen_score(
            user2, eth_signature, 2000, 3, 4, 2, 5, 3
        );
        env.call_private_void(update_score_interface2);

        let score_user1 = DegenScore::at(contract_address).get_degen_score(user1).simulate();
        let score_user2 = DegenScore::at(contract_address).get_degen_score(user2).simulate();

        assert(score_user1.value > 0, "User1 score should be greater than 0");
        assert(score_user2.value > 0, "User2 score should be greater than 0");
        assert(score_user2.value > score_user1.value, "User2 score should be greater than User1 score");
    }

    #[test]
    unconstrained fn test_zero_inputs() {
        let mut env = TestEnvironment::new();
        let owner = env.create_account();
        let user = env.create_account();
        env.impersonate(owner);

        let initializer = DegenScore::interface().constructor(owner);
        let degen_score_contract = env.deploy_self("DegenScore").with_private_initializer(initializer);
        let contract_address = degen_score_contract.to_address();

        let eth_signature = [0; 65];

        let update_score_interface = DegenScore::at(contract_address).update_degen_score(
            user, eth_signature, 0, 0, 0, 0, 0, 0
        );
        env.call_private_void(update_score_interface);

        let score = DegenScore::at(contract_address).get_degen_score(user).simulate();
        assert(score.value == 0, "Score should be 0 for zero inputs");
    }
}