#[starknet::contract]
mod ScavengerHunt {
    use starknet::event::EventEmitter;
    use starknet::ContractAddress;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
        StorageMapReadAccess, StorageMapWriteAccess
    };
    use onchain::interface::{IScavengerHunt, Question, Levels, PlayerProgress, LevelProgress};

    #[storage]
    struct Storage {
        questions: Map<u64, Question>,
        question_count: u64,
        questions_by_level: Map<(felt252, u64), u64>, // (levels, index) -> question_id
        question_per_level: u8,
        player_progress: Map<ContractAddress, PlayerProgress>,
        player_level_progress: Map<
            (ContractAddress, felt252), LevelProgress,
        > // (user, level) -> LevelProgress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        QuestionAdded: QuestionAdded,
        PlayerInitialized: PlayerInitialized
    }

    #[derive(Drop, starknet::Event)]
    pub struct QuestionAdded {
        pub question_id: u64,
        pub level: Levels,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PlayerInitialized {
        pub player_address: ContractAddress,
        pub level: felt252,
        pub is_initialized: bool
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl ScavengerHuntImpl of IScavengerHunt<ContractState> {
        //TODO: restrict to admin
        // Add a new question to the contract
        fn add_question(
            ref self: ContractState,
            level: Levels,
            question: ByteArray,
            answer: ByteArray,
            hint: ByteArray,
        ) {
            let question_id = self.question_count.read()
                + 1; // Increment the question count and use it as the ID

            self.question_count.write(question_id); // Update the question count

            let new_question = Question { question_id, question, answer, level, hint };

            // Store the new question in the `questions` map
            self.questions.write(question_id, new_question);

            // Store the new question by level

            self.questions_by_level.write((level.into(), question_id), question_id);

            // Emit event
            self.emit(QuestionAdded { question_id, level });
        }

        // Get a question by question_id
        fn get_question(self: @ContractState, question_id: u64) -> Question {
            // Retrieve the question from storage using the question_id

            self.questions.read(question_id)
        }

        fn set_question_per_level(ref self: ContractState, amount: u8) {
            assert!(amount > 0, "Question per level must be greater than 0");
            self.question_per_level.write(amount);
        }

        fn get_question_per_level(self: @ContractState, amount: u8) -> u8 {
            self.question_per_level.read()
        }

        fn initialize_player_progress(ref self: ContractState, player_address: ContractAddress) {
            let player_progress = self.player_progress.entry(player_address).read();

            assert!(!player_progress.is_initialized, "Player already initialized");

            // initialize player progess
            self
                .player_progress
                .write(
                    player_address,
                    PlayerProgress {
                        address: player_address, current_level: Levels::Easy, is_initialized: true
                    }
                );

            // set player current level
            self
                .player_level_progress
                .write(
                    (player_address, Levels::Easy.into()),
                    LevelProgress {
                        player: player_address,
                        level: Levels::Easy,
                        last_question_index: 0,
                        is_completed: false,
                        attempts: 0,
                        nft_minted: false
                    }
                );

            self.emit(PlayerInitialized { player_address, level: 'EASY', is_initialized: true });
        }
    }
}
