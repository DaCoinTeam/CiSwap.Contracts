import fs from "fs"

const outputFolder = __dirname + "/abis/"
const mainFolder = __dirname.slice(0, __dirname.lastIndexOf("\\")) + "/artifacts/contracts"

const createAbiFolder = (folderPath: string) => {
    try {
        if (!fs.existsSync(folderPath)) {
            fs.mkdirSync(folderPath)
        }
    } catch (err) {
        console.error(err)
    }
}

const extractAndWriteAbi = (filePath: string, outputFilePath: string) => {
    const data = fs.readFileSync(filePath)
    fs.writeFileSync(outputFilePath, JSON.stringify(JSON.parse(data.toString("utf-8")).abi))
}

const _extract = (folderAbsolutePath: string, outputAbsolutePath: string) => {
    console.log(folderAbsolutePath)

    if (folderAbsolutePath.includes(".sol")) {
        fs.readdirSync(folderAbsolutePath).forEach((file) => {
            if (!file.includes(".dbg.json")) {
                const finalPath = `${folderAbsolutePath}/${file}`
                const outputFilePath = `${outputAbsolutePath}/${file}`
                extractAndWriteAbi(finalPath, outputFilePath)
            }
        })
        return
    } 
    
    fs.readdirSync(folderAbsolutePath).forEach((folder) => {
        const _folderAbsolutePath = `${folderAbsolutePath}/${folder}`
        const _outputAbsolutePath = `${outputAbsolutePath}/${folder}`
        if (!fs.existsSync(_outputAbsolutePath)) {
            fs.mkdirSync(_outputAbsolutePath)
        }
        _extract(_folderAbsolutePath, _outputAbsolutePath)
    })
}

export const extractAbi = async () => {
    createAbiFolder(outputFolder)
    fs.readdirSync(mainFolder).forEach((folder) => {
        const folderAbsolutePath = mainFolder + "/" + folder
        const outputAbsolutePath = outputFolder + "/" + folder
        if (!fs.existsSync(outputAbsolutePath)) {
            fs.mkdirSync(outputAbsolutePath)
        }
        _extract(folderAbsolutePath, outputAbsolutePath)
    })
}
