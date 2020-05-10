// Sender: 0x01
// NFTを発行する（受取人: 0x02）

import NonFungibleToken, ExampleNFT from 0x01

transaction {
    let minter: &ExampleNFT.NFTMinter

    prepare(signer: AuthAccount) {
        self.minter = signer.borrow<&ExampleNFT.NFTMinter>(from: /storage/NFTMinter)!
    }

    execute {
        let recipient = getAccount(0x02)

        let receiver = recipient
            .getCapability(/public/NFTReceiver)!
            .borrow<&{NonFungibleToken.Receiver}>()!

        self.minter.mintNFT(recipient: receiver)

        log("ok")
    }
}