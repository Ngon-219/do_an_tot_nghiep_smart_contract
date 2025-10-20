import { ethers } from "hardhat";

async function main() {
    console.log("=".repeat(70));
    console.log("🚀 SMART CONTRACT DEPLOYMENT - EDUCATION MANAGEMENT SYSTEM");
    console.log("=".repeat(70));
    console.log();

    // Get deployer info
    const [deployer] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(deployer.address);
    
    console.log("👤 Deployer Information:");
    console.log("   Address:", deployer.address);
    console.log("   Balance:", ethers.formatEther(balance), "ETH");
    console.log();

    const deployedContracts: { [key: string]: string } = {};

    try {
        console.log("📦 [1/3] Deploying FactoryContract...");
        console.log("   (This will automatically deploy DataStorage and IssuanceOfDocument)");
        
        const FactoryContract = await ethers.getContractFactory("FactoryContract");
        const factoryContract = await FactoryContract.deploy();
        await factoryContract.waitForDeployment();
        
        const factoryAddress = await factoryContract.getAddress();
        deployedContracts["FactoryContract"] = factoryAddress;
        console.log("   ✅ FactoryContract:", factoryAddress);

        const dataStorageAddress = await factoryContract.getDataStorageAddress();
        const issuanceAddress = await factoryContract.getIssuanceContractAddress();
        
        deployedContracts["DataStorage"] = dataStorageAddress;
        deployedContracts["IssuanceOfDocument"] = issuanceAddress;
        
        console.log("   ✅ DataStorage:", dataStorageAddress);
        console.log("   ✅ IssuanceOfDocument:", issuanceAddress);
        console.log();

        console.log("📊 [2/3] Deploying StudentViolation Contract...");
        
        const deployScoreTx = await factoryContract.deployStudentScore();
        await deployScoreTx.wait();
        
        const studentScoreContracts = await factoryContract.getAllStudentScoreContracts();
        const studentViolationAddress = studentScoreContracts[studentScoreContracts.length - 1];
        
        deployedContracts["StudentViolation"] = studentViolationAddress;
        console.log("   ✅ StudentViolation:", studentViolationAddress);
        console.log();

        console.log("🗳️  [3/3] Deploying VotingContract...");
        
        const deployVotingTx = await factoryContract.deployVotingContract();
        await deployVotingTx.wait();
        
        const votingContracts = await factoryContract.getAllVotingContracts();
        const votingAddress = votingContracts[votingContracts.length - 1];
        
        deployedContracts["VotingContract"] = votingAddress;
        console.log("   ✅ VotingContract:", votingAddress);
        console.log();

        console.log("=".repeat(70));
        console.log("✅ ALL CONTRACTS DEPLOYED SUCCESSFULLY!");
        console.log("=".repeat(70));
        console.log();

        console.log("📋 DEPLOYMENT SUMMARY:");
        console.log("-".repeat(70));
        
        const contractOrder = [
            "FactoryContract",
            "DataStorage",
            "IssuanceOfDocument",
            "StudentViolation",
            "VotingContract"
        ];
        
        contractOrder.forEach((name) => {
            if (deployedContracts[name]) {
                const padding = " ".repeat(Math.max(0, 25 - name.length));
                console.log(`${name}${padding}: ${deployedContracts[name]}`);
            }
        });
        
        console.log("-".repeat(70));
        console.log();

        const systemInfo = await factoryContract.getSystemInfo();
        
        console.log("📊 SYSTEM INFORMATION:");
        console.log("-".repeat(70));
        console.log(`DataStorage Address       : ${systemInfo[0]}`);
        console.log(`IssuanceOfDocument Addr   : ${systemInfo[1]}`);
        console.log(`Total Students            : ${systemInfo[2].toString()}`);
        console.log(`Total Managers            : ${systemInfo[3].toString()}`);
        console.log(`StudentViolation Instances: ${systemInfo[4].toString()}`);
        console.log(`VotingContract Instances  : ${systemInfo[5].toString()}`);
        console.log("-".repeat(70));
        console.log();

        const network = await ethers.provider.getNetwork();
        
        console.log("🌐 NETWORK INFORMATION:");
        console.log("-".repeat(70));
        console.log(`Network Name              : ${network.name}`);
        console.log(`Chain ID                  : ${network.chainId.toString()}`);
        console.log(`Deployer Address          : ${deployer.address}`);
        console.log(`Deployment Time           : ${new Date().toISOString()}`);
        console.log("-".repeat(70));
        console.log();

        const fs = await import('fs');
        const deploymentData = {
            metadata: {
                network: network.name,
                chainId: network.chainId.toString(),
                deployedAt: new Date().toISOString(),
                deployerAddress: deployer.address,
                version: "1.0.0"
            },
            architecture: {
                description: "Centralized DataStorage pattern with Factory deployment",
                components: {
                    core: "DataStorage - Single source of truth for all data",
                    factory: "FactoryContract - Manages deployment and authorization",
                    logic: [
                        "IssuanceOfDocument - Manager signs documents",
                        "StudentViolation - Track violation points",
                        "VotingContract - Student voting system"
                    ]
                },
                roles: ["NONE", "STUDENT", "TEACHER", "ADMIN", "MANAGER"]
            },
            contracts: deployedContracts,
            systemInfo: {
                totalStudents: systemInfo[2].toString(),
                totalManagers: systemInfo[3].toString(),
                studentViolationInstances: systemInfo[4].toString(),
                votingContractInstances: systemInfo[5].toString()
            },
            quickStart: {
                "1_add_manager": {
                    contract: "DataStorage",
                    function: "addManager(address)",
                    description: "Add a manager who can sign documents"
                },
                "2_assign_teacher": {
                    contract: "DataStorage",
                    function: "assignRole(address, Role.TEACHER)",
                    description: "Assign teacher role to user"
                },
                "3_register_students": {
                    contract: "DataStorage",
                    function: "registerStudent(...) or registerStudentsBatch(...)",
                    description: "Register students to the system"
                },
                "4_initialize_violations": {
                    contract: "StudentViolation",
                    function: "initializeViolation(studentId, semester, points)",
                    description: "Initialize violation points for students"
                },
                "5_sign_documents": {
                    contract: "IssuanceOfDocument",
                    function: "signDocument(hash, studentId, type)",
                    description: "Manager signs documents for students"
                },
                "6_create_voting": {
                    contract: "VotingContract",
                    function: "createVotingEvent(name, description, options, duration)",
                    description: "Teacher/Manager creates voting events"
                }
            }
        };
        
        const filename = `deployment-${network.name}-${Date.now()}.json`;
        fs.writeFileSync(filename, JSON.stringify(deploymentData, null, 2));
        
        console.log("💾 DEPLOYMENT DATA SAVED:");
        console.log(`   File: ${filename}`);
        console.log();

        console.log("📝 NEXT STEPS TO USE THE SYSTEM:");
        console.log("-".repeat(70));
        console.log("1️⃣  Add Managers:");
        console.log("    → DataStorage.addManager(managerAddress)");
        console.log();
        console.log("2️⃣  Assign Teachers:");
        console.log("    → DataStorage.assignRole(teacherAddress, Role.TEACHER)");
        console.log();
        console.log("3️⃣  Register Students:");
        console.log("    → DataStorage.registerStudent(address, code, name, email)");
        console.log("    → DataStorage.registerStudentsBatch([addresses], [codes], [names], [emails])");
        console.log();
        console.log("4️⃣  Initialize Violation Points:");
        console.log("    → StudentViolation.initializeViolation(studentId, semester, initialPoints)");
        console.log();
        console.log("5️⃣  Start Operations:");
        console.log("    → Manager signs documents");
        console.log("    → Teacher manages violation points");
        console.log("    → Teacher/Manager creates voting events");
        console.log("    → Students vote");
        console.log("-".repeat(70));
        console.log();

        console.log("=".repeat(70));
        console.log("🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!");
        console.log("=".repeat(70));

    } catch (error) {
        console.error();
        console.error("❌ DEPLOYMENT FAILED!");
        console.error("=".repeat(70));
        console.error(error);
        throw error;
    }
}

main()
    .then(() => {
        console.log();
        process.exit(0);
    })
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });