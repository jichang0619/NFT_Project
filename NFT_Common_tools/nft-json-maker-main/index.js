const nftName = "JFFNFTPic2";
const description = "Test NFT Pic02";
const hiddenImgUrl = "ipfs://QmPq4LhFs2CorQhpqsT4YzgxPsfNf8WZMZqjbp9J4RK7xW";
const totalNum = 20;

try {
    for (let i = 1; i <= totalNum; i++) {
        let json = `{"name":"${nftName} #${i}","description":"${description}","image":"${hiddenImgUrl}/${i}.jpg","attributes":[{"trait_type": "Unknown","value": "Unknown"}]}`;
        let fs = require("fs");
        fs.writeFile(`json/${i}.json`, json, "utf8", (e)=>(e));
    }
    console.log("complete!");
} catch (error) {
    console.log(error);
}