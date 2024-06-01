task("deployCollateralPool", "Deploy CatastropheBondsCollateralPool contract")
    .setAction(async (taskArgs) => {
        const contractName = "CatastropheBondsCollateralPool";

        const networkName = network.name;

        console.log(contractName);

        console.log(`Deploying ${contractName} to ${networkName} network`);

        const collateralPoolFactory = await ethers.getContractFactory(contractName);

        const collateralPool = await collateralPoolFactory.deploy();

        await collateralPool.waitForDeployment();

        const address = await collateralPool.getAddress();

        console.log(`${contractName} deployed to ${address} on ${networkName} network.`);

    })

module.exports = {}