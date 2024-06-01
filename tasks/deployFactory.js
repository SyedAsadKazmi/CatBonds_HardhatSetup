task("deployFactory", "Deploy CatastropheBondsFactory contract")
    .addPositionalParam("collateralPoolAddress", "The collateralPoolAddress of the contract that you want to deploy")
    .setAction(async (taskArgs) => {
        const contractName = "CatastropheBondsFactory"

        const collateralPoolAddress = taskArgs.collateralPoolAddress

        const networkName = network.name

        console.log(contractName)

        console.log(`Deploying ${contractName} to ${networkName} network`)

        const factoryFactory = await ethers.getContractFactory(contractName)

        const factory = await factoryFactory.deploy(collateralPoolAddress);

        await factory.waitForDeployment();

        const address = await factory.getAddress()

        console.log(`${contractName} deployed to ${address} on ${networkName} network.`)

    })

module.exports = {}