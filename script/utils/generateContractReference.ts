import { docgen } from "solidity-docgen";
import fs from "fs/promises";
import { rootFolder } from "../helpers/generateContractList";
import { join } from "path";
import { execSync } from "child_process";

/**
 * DEV NOTE:
 *
 * There are some issues with prb-math libraries and other similar libraries that have multiple
 * solidity files with the same name. The artifact files overwrite each other, causing issues
 * during the doc generation. This script takes care of those conflicts by ignoring a dependency
 * if it cannot be found in the artifacts. So far, this has not affected documentation quality.
 *
 * However, there are some issues where the docgen library fails because of this. A simple hack
 * fixes the errors by changing the line at `node_modules/solidity-docgen/dist/utils/scope.js:34`
 * to the following:
 *
 * ```
 * if (typeof importedScope[a.foreign.name] === "function") {
 *   scope[a.local ?? a.foreign.name] = importedScope[a.foreign.name] ?? (() =>  importedScope[a.foreign.name]());
 * }
 * ```
 *
 * This prevents it from trying to access a scope that is not available.
 */

const gitUrl = "https://github.com/GenerationSoftware";
const solcOutDir = join(rootFolder, "out");

console.log(
  "Generating solidity docs from `out` artifacts... If the script is failing, and you haven't applied the hack necessary, please see the DEV NOTE in this script."
);

const getJsonFilePaths = async (dir: string) => {
  const jsonFilePaths: string[] = [];
  for (const f of await fs.readdir(dir)) {
    if (f.endsWith(".json")) {
      jsonFilePaths.push(join(dir, f));
    } else {
      const childJsonPaths = await getJsonFilePaths(join(dir, f));
      jsonFilePaths.push(...childJsonPaths);
    }
  }
  return jsonFilePaths;
};

const addSourcesToMap = (solc: any, map: any, solcNodes: any) => {
  const nodesToRemove = [];
  for (const node of solc.ast.nodes) {
    if (node.nodeType === "ImportDirective") {
      const nodeSolc = solcNodes[node.absolutePath];
      if (!nodeSolc) {
        // console.warn(`Failed to find source ${node.absolutePath} in solc node map.`);
        nodesToRemove.push(node);
      } else {
        if (!map[node.absolutePath]) {
          map[node.absolutePath] = nodeSolc;
          // console.log(`Added: ${node.absolutePath}`);
          addSourcesToMap(nodeSolc, map, solcNodes); // recurse
        }
      }
    }
  }
  solc.ast.nodes = solc.ast.nodes.filter((node) => {
    if (nodesToRemove.includes(node)) {
      // console.log(`Removed: ${node.absolutePath}`);
      return false;
    } else {
      return true;
    }
  });
};

const buildOutputSourceMap = async (solc: any, outDir: string) => {
  // Build source node map
  const solcNodes = {};
  for (const solcFilename of await getJsonFilePaths(outDir)) {
    const solc = JSON.parse(await fs.readFile(solcFilename, "utf-8"));
    if (solc.ast) {
      solcNodes[solc.ast.absolutePath] = solc;
    }
  }
  const map: Record<string, any> = { [solc.ast.absolutePath]: solc };
  addSourcesToMap(solc, map, solcNodes);
  return map;
};

const gitSourceLink = (repo: string, path: string) => {
  const out = execSync(`cd lib/${repo} && git show`).toString("utf-8");
  const commit = out.match(/(?<=commit\s)[0-9a-f]+(?=\s)/)[0];
  return `[Git Source](${gitUrl}/${repo}/blob/${commit}/${path})`;
};

const solcBuild = async (solc: any, outDir: string) => {
  return {
    input: solc.metadata,
    output: {
      sources: await buildOutputSourceMap(solc, outDir),
    },
  };
};

const main = async () => {
  // Prize Pool
  {
    const prizePoolSolc = JSON.parse(
      await fs.readFile("out/PrizePool.sol/PrizePool.json", "utf-8")
    );
    const prizePoolDir = join(rootFolder, "reference-out/prize-pool");
    const prizePoolDocFile = join(prizePoolDir, "index.md");
    await docgen([await solcBuild(prizePoolSolc, solcOutDir)], {
      outputDir: prizePoolDir,
      templates: join(rootFolder, "script/utils/templates"),
      root: rootFolder,
      sourcesDir: "lib/pt-v5-prize-pool/src/",
      pages: "single",
      exclude: ["libraries"],
    });
    await fs.writeFile(
      prizePoolDocFile,
      `${gitSourceLink("pt-v5-prize-pool", "src/PrizePool.sol")}\n\n` +
        (await fs.readFile(prizePoolDocFile, "utf-8"))
    );
  }

  // Vault & Vault Factory
  {
    const vaultSolc = JSON.parse(
      await fs.readFile(join(solcOutDir, "Vault.sol/Vault.json"), "utf-8")
    );
    const vaultFactorySolc = JSON.parse(
      await fs.readFile(join(solcOutDir, "VaultFactory.sol/VaultFactory.json"), "utf-8")
    );
    const iVaultHooksSolc = JSON.parse(
      await fs.readFile(join(solcOutDir, "IVaultHooks.sol/IVaultHooks.json"), "utf-8")
    );
    const outDir = join(rootFolder, "reference-out/vault");
    await docgen(
      [
        await solcBuild(vaultSolc, solcOutDir),
        await solcBuild(vaultFactorySolc, solcOutDir),
        await solcBuild(iVaultHooksSolc, solcOutDir),
      ],
      {
        outputDir: outDir,
        templates: join(rootFolder, "script/utils/templates"),
        root: rootFolder,
        sourcesDir: "lib/pt-v5-vault/src",
        pages: "files",
      }
    );
    await fs.writeFile(
      join(outDir, "Vault.md"),
      `${gitSourceLink("pt-v5-vault", "src/Vault.sol")}\n\n` +
        (await fs.readFile(join(outDir, "Vault.md"), "utf-8"))
    );
    await fs.writeFile(
      join(outDir, "VaultFactory.md"),
      `${gitSourceLink("pt-v5-vault", "src/VaultFactory.sol")}\n\n` +
        (await fs.readFile(join(outDir, "VaultFactory.md"), "utf-8"))
    );
    await fs.writeFile(
      join(outDir, "interfaces/IVaultHooks.md"),
      `${gitSourceLink("pt-v5-vault", "src/interfaces/IVaultHooks.sol")}\n\n` +
        (await fs.readFile(join(outDir, "interfaces/IVaultHooks.md"), "utf-8"))
    );
  }

  // CGDA Liquidator
  {
    const liquidationPairSolc = JSON.parse(
      await fs.readFile(join(solcOutDir, "LiquidationPair.sol/LiquidationPair.json"), "utf-8")
    );
    const liquidationRouterSolc = JSON.parse(
      await fs.readFile(join(solcOutDir, "LiquidationRouter.sol/LiquidationRouter.json"), "utf-8")
    );
    const liquidationPairFactorySolc = JSON.parse(
      await fs.readFile(
        join(solcOutDir, "LiquidationPairFactory.sol/LiquidationPairFactory.json"),
        "utf-8"
      )
    );
    const continuousGDASolc = JSON.parse(
      await fs.readFile(join(solcOutDir, "ContinuousGDA.sol/ContinuousGDA.json"), "utf-8")
    );
    const safeSD59x18Solc = JSON.parse(
      await fs.readFile(join(solcOutDir, "SafeSD59x18.sol/SafeSD59x18.json"), "utf-8")
    );
    const outDir = join(rootFolder, "reference-out/cgda-liquidator");
    await docgen(
      [
        await solcBuild(liquidationPairSolc, solcOutDir),
        await solcBuild(liquidationRouterSolc, solcOutDir),
        await solcBuild(liquidationPairFactorySolc, solcOutDir),
        await solcBuild(continuousGDASolc, solcOutDir),
        await solcBuild(safeSD59x18Solc, solcOutDir),
      ],
      {
        outputDir: outDir,
        templates: join(rootFolder, "script/utils/templates"),
        root: rootFolder,
        sourcesDir: "lib/pt-v5-cgda-liquidator/src",
        pages: "files",
        exclude: ["libraries"],
      }
    );
    await fs.writeFile(
      join(outDir, "LiquidationPair.md"),
      `${gitSourceLink("pt-v5-cgda-liquidator", "src/LiquidationPair.sol")}\n\n` +
        (await fs.readFile(join(outDir, "LiquidationPair.md"), "utf-8"))
    );
    await fs.writeFile(
      join(outDir, "LiquidationRouter.md"),
      `${gitSourceLink("pt-v5-cgda-liquidator", "src/LiquidationRouter.sol")}\n\n` +
        (await fs.readFile(join(outDir, "LiquidationRouter.md"), "utf-8"))
    );
    await fs.writeFile(
      join(outDir, "LiquidationPairFactory.md"),
      `${gitSourceLink("pt-v5-cgda-liquidator", "src/LiquidationPairFactory.sol")}\n\n` +
        (await fs.readFile(join(outDir, "LiquidationPairFactory.md"), "utf-8"))
    );
  }

  // Chainlink VRF V2 Direct
  {
    const chainlinkVrfV2Direct = JSON.parse(
      await fs.readFile(
        join(solcOutDir, "ChainlinkVRFV2Direct.sol/ChainlinkVRFV2Direct.json"),
        "utf-8"
      )
    );
    const chainlinkVrfV2DirectRngAuctionHelper = JSON.parse(
      await fs.readFile(
        join(
          solcOutDir,
          "ChainlinkVRFV2DirectRngAuctionHelper.sol/ChainlinkVRFV2DirectRngAuctionHelper.json"
        ),
        "utf-8"
      )
    );
    const iRngAuctionSolc = JSON.parse(
      await fs.readFile(join(solcOutDir, "IRngAuction.sol/IRngAuction.json"), "utf-8")
    );
    const outDir = join(rootFolder, "reference-out/chainlink-vrf-v2-direct");
    await docgen(
      [
        await solcBuild(chainlinkVrfV2Direct, solcOutDir),
        await solcBuild(chainlinkVrfV2DirectRngAuctionHelper, solcOutDir),
        await solcBuild(iRngAuctionSolc, solcOutDir),
      ],
      {
        outputDir: outDir,
        templates: join(rootFolder, "script/utils/templates"),
        root: rootFolder,
        sourcesDir: "lib/pt-v5-chainlink-vrf-v2-direct/src",
        pages: "files",
        exclude: ["libraries"],
      }
    );
    await fs.writeFile(
      join(outDir, "ChainlinkVRFV2Direct.md"),
      `${gitSourceLink("pt-v5-chainlink-vrf-v2-direct", "src/ChainlinkVRFV2Direct.sol")}\n\n` +
        (await fs.readFile(join(outDir, "ChainlinkVRFV2Direct.md"), "utf-8"))
    );
    await fs.writeFile(
      join(outDir, "ChainlinkVRFV2DirectRngAuctionHelper.md"),
      `${gitSourceLink(
        "pt-v5-chainlink-vrf-v2-direct",
        "src/ChainlinkVRFV2DirectRngAuctionHelper.sol"
      )}\n\n` +
        (await fs.readFile(join(outDir, "ChainlinkVRFV2DirectRngAuctionHelper.md"), "utf-8"))
    );
    await fs.writeFile(
      join(outDir, "interfaces/IRngAuction.md"),
      `${gitSourceLink("pt-v5-chainlink-vrf-v2-direct", "src/interfaces/IRngAuction.sol")}\n\n` +
        (await fs.readFile(join(outDir, "interfaces/IRngAuction.md"), "utf-8"))
    );
  }

  // Claimer
  {
    const claimerSolc = JSON.parse(
      await fs.readFile(join(solcOutDir, "Claimer.sol/Claimer.json"), "utf-8")
    );
    const claimerFactorySolc = JSON.parse(
      await fs.readFile(join(solcOutDir, "ClaimerFactory.sol/ClaimerFactory.json"), "utf-8")
    );
    const linearVrgdaLibSolc = JSON.parse(
      await fs.readFile(join(solcOutDir, "LinearVRGDALib.sol/LinearVRGDALib.json"), "utf-8")
    );
    const outDir = join(rootFolder, "reference-out/claimer");
    await docgen(
      [
        await solcBuild(claimerSolc, solcOutDir),
        await solcBuild(claimerFactorySolc, solcOutDir),
        await solcBuild(linearVrgdaLibSolc, solcOutDir),
      ],
      {
        outputDir: outDir,
        templates: join(rootFolder, "script/utils/templates"),
        root: rootFolder,
        sourcesDir: "lib/pt-v5-claimer/src",
        pages: "files",
        exclude: ["libraries"],
      }
    );
    await fs.writeFile(
      join(outDir, "Claimer.md"),
      `${gitSourceLink("pt-v5-claimer", "src/Claimer.sol")}\n\n` +
        (await fs.readFile(join(outDir, "Claimer.md"), "utf-8"))
    );
    await fs.writeFile(
      join(outDir, "ClaimerFactory.md"),
      `${gitSourceLink("pt-v5-claimer", "src/ClaimerFactory.sol")}\n\n` +
        (await fs.readFile(join(outDir, "ClaimerFactory.md"), "utf-8"))
    );
  }

  // Draw Auction
  {
    const repoName = "pt-v5-draw-auction";
    const sources = [
      "AddressRemapper.sol/AddressRemapper.json",
      "RngAuctionRelayer.sol/RngAuctionRelayer.json",
      "IAuction.sol/IAuction.json",
      "IRngAuctionRelayListener.sol/IRngAuctionRelayListener.json",
      "RewardLib.sol/RewardLib.json",
      "RngAuction.sol/RngAuction.json",
      "RngAuctionRelayerDirect.sol/RngAuctionRelayerDirect.json",
      "RngAuctionRelayerRemoteOwner.sol/RngAuctionRelayerRemoteOwner.json",
      "RngRelayAuction.sol/RngRelayAuction.json",
    ];
    const outFileNames = [
      "abstract/AddressRemapper",
      "abstract/RngAuctionRelayer",
      "interfaces/IAuction",
      "interfaces/IRngAuctionRelayListener",
      "RngAuction",
      "RngAuctionRelayerDirect",
      "RngAuctionRelayerRemoteOwner",
      "RngRelayAuction",
    ];
    const builds = [];
    for (const source of sources) {
      builds.push(
        await solcBuild(
          JSON.parse(await fs.readFile(join(solcOutDir, source), "utf-8")),
          solcOutDir
        )
      );
    }
    const outDir = join(rootFolder, "reference-out/draw-auction");
    await docgen(builds, {
      outputDir: outDir,
      templates: join(rootFolder, "script/utils/templates"),
      root: rootFolder,
      sourcesDir: `lib/${repoName}/src`,
      pages: "files",
      exclude: ["libraries"],
    });
    for (const outFileName of outFileNames) {
      await fs.writeFile(
        join(outDir, `${outFileName}.md`),
        `${gitSourceLink(repoName, `src/${outFileName}.sol`)}\n\n` +
          (await fs.readFile(join(outDir, `${outFileName}.md`), "utf-8"))
      );
    }
  }

  // Twab Controller
  {
    const repoName = "pt-v5-twab-controller";
    const sources = [
      "ObservationLib.sol/ObservationLib.json",
      "TwabLib.sol/TwabLib.json",
      "TwabController.sol/TwabController.json",
    ];
    const outFileNames = ["TwabController"];
    const builds = [];
    for (const source of sources) {
      builds.push(
        await solcBuild(
          JSON.parse(await fs.readFile(join(solcOutDir, source), "utf-8")),
          solcOutDir
        )
      );
    }
    const outDir = join(rootFolder, "reference-out/twab-controller");
    await docgen(builds, {
      outputDir: outDir,
      templates: join(rootFolder, "script/utils/templates"),
      root: rootFolder,
      sourcesDir: `lib/${repoName}/src`,
      pages: "files",
      exclude: ["libraries"],
    });
    for (const outFileName of outFileNames) {
      await fs.writeFile(
        join(outDir, `${outFileName}.md`),
        `${gitSourceLink(repoName, `src/${outFileName}.sol`)}\n\n` +
          (await fs.readFile(join(outDir, `${outFileName}.md`), "utf-8"))
      );
    }
  }

  // Twab Delegator
  {
    const repoName = "pt-v5-twab-delegator";
    const sources = [
      "Delegation.sol/Delegation.json",
      "LowLevelDelegator.sol/LowLevelDelegator.json",
      "PermitAndMulticall.sol/PermitAndMulticall.json",
      "TwabDelegator.sol/TwabDelegator.json",
    ];
    const outFileNames = ["Delegation", "LowLevelDelegator", "PermitAndMulticall", "TwabDelegator"];
    const builds = [];
    for (const source of sources) {
      builds.push(
        await solcBuild(
          JSON.parse(await fs.readFile(join(solcOutDir, source), "utf-8")),
          solcOutDir
        )
      );
    }
    const outDir = join(rootFolder, "reference-out/twab-delegator");
    await docgen(builds, {
      outputDir: outDir,
      templates: join(rootFolder, "script/utils/templates"),
      root: rootFolder,
      sourcesDir: `lib/${repoName}/src`,
      pages: "files",
      exclude: ["libraries"],
    });
    for (const outFileName of outFileNames) {
      await fs.writeFile(
        join(outDir, `${outFileName}.md`),
        `${gitSourceLink(repoName, `src/${outFileName}.sol`)}\n\n` +
          (await fs.readFile(join(outDir, `${outFileName}.md`), "utf-8"))
      );
    }
  }

  // Vault Booster
  {
    const repoName = "pt-v5-vault-boost";
    const sources = [
      "VaultBooster.sol/VaultBooster.json",
      "VaultBoosterFactory.sol/VaultBoosterFactory.json",
    ];
    const outFileNames = ["VaultBooster", "VaultBoosterFactory"];
    const builds = [];
    for (const source of sources) {
      builds.push(
        await solcBuild(
          JSON.parse(await fs.readFile(join(solcOutDir, source), "utf-8")),
          solcOutDir
        )
      );
    }
    const outDir = join(rootFolder, "reference-out/vault-boost");
    await docgen(builds, {
      outputDir: outDir,
      templates: join(rootFolder, "script/utils/templates"),
      root: rootFolder,
      sourcesDir: `lib/${repoName}/src`,
      pages: "files",
      exclude: ["libraries"],
    });
    for (const outFileName of outFileNames) {
      await fs.writeFile(
        join(outDir, `${outFileName}.md`),
        `${gitSourceLink(repoName, `src/${outFileName}.sol`)}\n\n` +
          (await fs.readFile(join(outDir, `${outFileName}.md`), "utf-8"))
      );
    }
  }
};
main();
