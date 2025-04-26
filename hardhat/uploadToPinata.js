require("dotenv").config();
const axios = require("axios");
const FormData = require("form-data");
const fs = require("fs");
const path = require("path");

const PINATA_JWT = process.env.PINATA_JWT;
const METADATA_FOLDER_PATH = path.join(__dirname, "Metadata");

async function uploadFolderToPinata() {
  const formData = new FormData();

  // Add Pinata options and metadata
  formData.append("pinataOptions", JSON.stringify({ cidVersion: 1 }));
  formData.append("pinataMetadata", JSON.stringify({ name: "MarketSentimentNFTs" }));

  // Read all files from Metadata folder and add to formData
  const files = fs.readdirSync(METADATA_FOLDER_PATH);
  for (const file of files) {
    const filePath = path.join(METADATA_FOLDER_PATH, file);
    formData.append("file", fs.createReadStream(filePath), {
      filepath: `Metadata/${file}`
    });
  }

  try {
    const res = await axios.post("https://api.pinata.cloud/pinning/pinFileToIPFS", formData, {
      maxContentLength: Infinity,
      maxBodyLength: Infinity,
      headers: {
        Authorization: `Bearer ${PINATA_JWT}`,
        ...formData.getHeaders(),
      },
    });

    console.log("✅ Folder uploaded! CID:", res.data.IpfsHash);
  } catch (err) {
    console.error("❌ Error uploading folder:", err.response?.data || err.message);
  }
}

uploadFolderToPinata();