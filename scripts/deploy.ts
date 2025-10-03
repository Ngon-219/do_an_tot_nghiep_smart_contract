import { ethers } from "hardhat";

async function main() {
    console.log("=".repeat(50));
    console.log("STARTING DEPLOYMENT OF ALL CONTRACTS");
    console.log("=".repeat(50));

    // Get deployer account
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");
    console.log();

    const deployedContracts: { [key: string]: string } = {};

    try {
        console.log("Deploying FactoryContract...");
        const factoryContract = await ethers.deployContract("FactoryContract");
        await factoryContract.waitForDeployment();
        const factoryAddress = await factoryContract.getAddress();
        deployedContracts["FactoryContract"] = factoryAddress;
        console.log("FactoryContract deployed to:", factoryAddress);

        console.log("Deploying StudentScore...");
        const studentScore = await ethers.deployContract("StudentScore", [factoryAddress]);
        await studentScore.waitForDeployment();
        const studentScoreAddress = await studentScore.getAddress();
        deployedContracts["StudentScore"] = studentScoreAddress;
        console.log("StudentScore deployed to:", studentScoreAddress);
        console.log();

        console.log("Deploying VotingContract...");
        const votingContract = await ethers.deployContract("VotingContract", [factoryAddress]);
        await votingContract.waitForDeployment();
        const votingContractAddress = await votingContract.getAddress();
        deployedContracts["VotingContract"] = votingContractAddress;
        console.log("VotingContract deployed to:", votingContractAddress);
        console.log();

        // Final summary
        console.log("=".repeat(50));
        console.log("ALL CONTRACTS DEPLOYED SUCCESSFULLY!");
        console.log("=".repeat(50));
        console.log("DEPLOYMENT SUMMARY:");
        console.log("-".repeat(50));
        
        Object.entries(deployedContracts).forEach(([name, address]) => {
            console.log(`${name.padEnd(20)} : ${address}`);
        });
        
        console.log("-".repeat(50));
        const network = await ethers.provider.getNetwork();
        console.log("Network:", network.name);
        console.log("=".repeat(50));

        // Save deployment addresses to file
        const fs = await import('fs');
        const deploymentData = {
            network: network.name,
            chainId: network.chainId.toString(),
            timestamp: new Date().toISOString(),
            deployer: deployer.address,
            contracts: deployedContracts
        };
        
        fs.writeFileSync(
            `deployments-${network.name}-${Date.now()}.json`, 
            JSON.stringify(deploymentData, null, 2)
        );
        console.log("Deployment addresses saved to file");

    } catch (error) {
        console.error("DEPLOYMENT FAILED!");
        console.error("Error:", error);
        throw error;
    }
}

// Execute deployment
main()
    .then(() => {
        console.log("Deployment completed successfully!");
        process.exit(0);
    })
    .catch((error) => {
        console.error("Deployment failed:", error);
        process.exit(1);
    });