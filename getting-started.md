# Obol Dappnode Package QuickStart Guide

For detailed steps and screenshots, please refer to [Obol docs](https://docs.obol.org/docs/start/quickstart_group).

### Preparing your Ethereum node (pre-requisite)

1. Go to [Stakers tab](http://my.dappnode/stakers/ethereum) and select the desired network (Ethereum mainnet, hoodi, holesky...)
2. Choose an execution client (e.g. Nethermind) and a consensus client (e.g. Lodestar)
3. Click "Apply changes" and wait for install and sync processes.

### Cluster Configuration

This Obol package supports up to 5 clusters. Each of them requires the Charon DV middleware and an Ethereum validator client, which are already included inside the services provided by the package.

During the **first installation**, leave all definition file inputs blank to obtain the ENR for each Charon node, necessary for the DKG process.

### View Package Info

Under the Info tab, see pre-generated ENRs and validator containers' status.

### Create a DV cluster on Obol launchpad

1. Use the appropriate launchpad for your network:
   - [Mainnet Launchpad](https://mainnet.launchpad.obol.org/)
   - [Gnosis Launchpad](https://gnosischain.launchpad.obol.org/)
   - [Holesky Launchpad](https://holesky.launchpad.obol.org/)
   - [Hoodi Launchpad](https://hoodi.launchpad.obol.org/)

2. Follow instructions to sign with your wallet and provide an ENR from the DappNode info section
3. Obtain the cluster definition file URL for the DKG ceremony. [More info](https://docs.obol.org/docs/start/quickstart_group#install-the-obol-dappnode-package)

### Running the Distributed Key Generation Ceremony (DKG)

1. Import the definition file:

   - Go to the Config tab of your Obol package
   - Select URL from the Dropdown menu
   - Paste the definition file URL into the cluster number matching the ENR you used for creating the cluster. Example: If you used ENR1 for signing, paste the URL into Cluster-1. This URL must follow the format: `https://api.obol.tech/dv/0xf9632c4333e4d67373b383da56dfb764df47268881d3412a1eef1a0247dc7367`
   - Click `Update` button at the bottom of the page.

2. Monitor the DKG process via the Logs tab. [More info](https://docs.obol.org/docs/start/quickstart_group#step-3-run-the-distributed-key-generation-dkg-ceremony)

### Exiting a validator

1. Navigate to the package Config tab
2. Click on `Show advanced editor`
3. Scroll to the relevant cluster number and type `true` next to `SIGN_EXIT`
4. Click on `Update` and check logs to confirm the exit process has been successful.

### Container status

Stopped containers for inactive clusters are normal. This saves system resources.

### Backup

It's recommended to save a backup of the relevant data of each cluster. You can download it from the Backup tab of the package. There, you can also restore a backup after you have provided the `definition-file-url` in the setup wizard or in the Config of the package.

### Upload a Node Artifact

If you have been given a Node Artifact (e.g. `node0.zip`) you can either import it on install (by choosing "File upload" mode) or import it later in the package File Manager tab by choosing the service you want to import it to (`cluster-<number>`) and setting `/import/` as the destination path before clicking "Upload".

For support, you can join [Obol discord](https://discord.com/invite/n6ebKsX46w)
