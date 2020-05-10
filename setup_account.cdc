// Sender: 0x02
// NFT受取の準備を行う

import NonFungibleToken, ExampleNFT from 0x01

transaction {
    prepare(signer: AuthAccount) {
        let collection <- ExampleNFT.createEmptyCollection()

        // let oldCol <- signer.load<@ExampleNFT.Collection>(from: /storage/NFTCollection)
        // destroy oldCol

        signer.save(<-collection, to: /storage/NFTCollection)

        signer.link<&{NonFungibleToken.Receiver, ExampleNFT.CollectionBorrow}>(
            /public/NFTReceiver,
            target: /storage/NFTCollection
        )

        log("ok")
    }
}