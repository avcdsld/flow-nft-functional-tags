// Sender: 0x02
// 借用タグが付いている NFT を取り戻す

import NonFungibleToken, ExampleNFT from 0x01

transaction {
    prepare(signer: AuthAccount) {
        let acct = getAccount(0x01)

        let collectionBorrowRef = acct
            .getCapability(/public/NFTReceiver)!
            .borrow<&{NonFungibleToken.Receiver, ExampleNFT.CollectionBorrow}>()!
        var token = collectionBorrowRef.borrowNFT(id: 0)
        log("before token:")
        log(token)

        collectionBorrowRef.getBackNFT(id: 0)

        token = collectionBorrowRef.borrowNFT(id: 0)
        log("after token:")
        log(token)

        // let collectionBorrowRef = acct
        //     .getCapability(/public/NFTReceiver)!
        //    .borrow<&{ExampleNFT.CollectionBorrow}>()!
        // collectionBorrowRef.getBackNFT(id: 0)

        log("ok")
    }
}
