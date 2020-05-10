pub contract interface NonFungibleToken {
    pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub resource interface INFT {
        pub let id: UInt64
    }

    pub resource NFT: INFT {
        pub let id: UInt64
    }

    pub resource interface Provider {
        pub fun withdraw(withdrawID: UInt64): @NFT {
            post {
                result.id == withdrawID: "The ID of the withdrawn token must be the same as the requested ID"
            }
        }

        pub fun batchWithdraw(ids: [UInt64]): @Collection {
            post {
                result.getIDs().length == ids.length: "Withdrawn collection does not match the requested IDs"
            }
        }
    }

    pub resource interface Receiver {
		pub fun deposit(token: @NFT)
        pub fun batchDeposit(tokens: @Collection)
    }

    pub resource Collection: Provider, Receiver {
        pub var ownedNFTs: @{UInt64: NFT}

        pub fun withdraw(withdrawID: UInt64): @NFT
        pub fun batchWithdraw(ids: [UInt64]): @Collection
        pub fun deposit(token: @NFT)
        pub fun batchDeposit(tokens: @Collection)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NFT
    }

    pub fun createEmptyCollection(): @Collection {
        post {
            result.getIDs().length == 0: "The created collection must be empty!"
        }
    }
}


pub contract ExampleNFT: NonFungibleToken {
    pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    // NFTに持たせることで、様々な機能を提供するリソースオブジェクト
    pub resource interface FunctionalTag {
        pub let creator: Address
        pub fun getTagType(): String
    }

    // 借用品であることを示すタグ
    pub resource BorrowingTag: FunctionalTag {
        pub let creator: Address
        pub let lender: Address

        init(creator: Address, lender: Address) {
            self.creator = creator
            self.lender = lender
        }

        pub fun getTagType(): String {
            return "BorrowingTag"
        }
    }

    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64
        pub var metadata: {String: String}
        access(contract) var borrowingTag: @{String: BorrowingTag} // 借用タグ  // メモ: ディクショナリにしないと、代入時にエラーが出る
                                                                              // Checking failed: cannot assign to `borrowingTag`: field has public access. has public access. Consider making it publicly settable cannot assign to resource-typed target. consider force assigning (<-!) or swapping (<->)

        init(initID: UInt64) {
            self.id = initID
            self.metadata = {}
            self.borrowingTag <- {}
        }

        destroy() {
            destroy self.borrowingTag
        }
    }

    pub resource interface CollectionBorrow {
        pub fun borrowNFT(id: UInt64): &NFT
        pub fun getBackNFT(id: UInt64)
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver {
        pub var ownedNFTs: @{UInt64: NFT}

        init () {
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        pub fun batchWithdraw(ids: [UInt64]): @Collection {
            let batchCollection <- create Collection()
            for id in ids {
                let nft <- self.withdraw(withdrawID: id)
                batchCollection.deposit(token: <-nft)
            }
            return <-batchCollection
        }

        pub fun deposit(token: @NFT) {
            let id: UInt64 = token.id
            let oldToken <- self.ownedNFTs[id] <- token
            emit Deposit(id: id, to: self.owner?.address)
            destroy oldToken
        }

        pub fun batchDeposit(tokens: @Collection) {
            for id in tokens.getIDs() {
                let nft <- tokens.withdraw(withdrawID: id)
                self.deposit(token: <-nft)
            }
            destroy tokens
        }

        // NFTに借用タグを付ける
        pub fun attachBorrowingTag(id: UInt64) {
            let token <- self.ownedNFTs.remove(key: id) ?? panic("missing NFT")

            let creator = self.owner!.address
            token.borrowingTag["BorrowingTag"] <-! create BorrowingTag(creator: creator, lender: creator)

            self.ownedNFTs[id] <-! token
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NFT {
            return &self.ownedNFTs[id] as &NFT
        }

        // 借用タグに書かれている貸主に NFT を返す
        pub fun getBackNFT(id: UInt64) {
            let token <- self.ownedNFTs.remove(key: id) ?? panic("missing NFT")

            let tag <- token.borrowingTag.remove(key: "BorrowingTag") ?? panic("missing borrowingTag")
            let receiver = getAccount(tag.lender)
                    .getCapability(/public/NFTReceiver)!
                    .borrow<&{NonFungibleToken.Receiver}>()!
            destroy tag

            emit Withdraw(id: token.id, from: self.owner?.address)
            receiver.deposit(token: <-token)
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

	pub resource NFTMinter {
		pub fun mintNFT(recipient: &{NonFungibleToken.Receiver}) {
			var newNFT <- create NFT(initID: ExampleNFT.totalSupply)
			recipient.deposit(token: <-newNFT)
            ExampleNFT.totalSupply = ExampleNFT.totalSupply + UInt64(1)
		}
	}

	init() {
        self.totalSupply = 0

        let oldCol <- self.account.load<@ExampleNFT.Collection>(from: /storage/NFTCollection)
        destroy oldCol

        let collection <- create Collection()
        self.account.save(<-collection, to: /storage/NFTCollection)

        self.account.link<&{NonFungibleToken.Receiver, CollectionBorrow}>(
            /public/NFTReceiver,
            target: /storage/NFTCollection
        )

        let minter <- create NFTMinter()
        self.account.save(<-minter, to: /storage/NFTMinter)

        emit ContractInitialized()
	}
}
