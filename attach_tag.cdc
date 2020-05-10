// Sender: 0x02
// NFTに借用タグを付けて、その後、送付する

import NonFungibleToken, ExampleNFT from 0x01

transaction {
    let token: @ExampleNFT.NFT

    prepare(signer: AuthAccount) {
        let collectionRef = signer.borrow<&ExampleNFT.Collection>(from: /storage/NFTCollection)!

        collectionRef.attachBorrowingTag(id: 0)

        self.token <- collectionRef.withdraw(withdrawID: 0)
    }

    execute {
        log("token:")
        log(self.token.id)
        log(self.token.metadata)
        // self.receiverRef.deposit(token: <-self.token)

        let recipient = getAccount(0x01)
        let receiverRef = recipient
            .getCapability(/public/NFTReceiver)!
            .borrow<&{NonFungibleToken.Receiver}>()!
        receiverRef.deposit(token: <-self.token)

        log("ok")
    }
}
