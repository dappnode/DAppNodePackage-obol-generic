# Obol Dappnode Package

This package runs **Obol's Charon** client, a [distributed validator](https://docs.obol.org/learn/readme/key-concepts) (DV) middleware, along with a **Prometheus metrics service** and a **validator client**. It allows you to run up to five DV clusters with different configurations, interacting with the Ethereum blockchain.

### Services

This package includes the following services:

- **Obol Charon (`cluster-x`)**:

  - Obol Charon enables any Ethereum validator client to operate as part of a distributed validator (DV). It sits as middleware between the validator client and the beacon node, proxying API traffic and coordinating with other Charon nodes in a cluster to reach consensus on validator duties. The system is Byzantine-fault tolerant, as long as a majority of nodes are honest.

  - A supervisor daemon ensures that the Charon service and validator client are started properly. It runs scripts in `/usr/local/bin/scripts/charon` to handle the file import process, run the Charon middleware, and manage the DV cluster.

  - Configuration files for Charon are managed in `/opt/charon/.charon` for each cluster instance.

- **Validator Client (`lodestar`)**:

  - The validator client is based on **Lodestar**, a popular Ethereum consensus client. It manages validator duties and communicates with the beacon node.

  - Scripts in `/usr/local/bin/scripts/lodestar` handle validator operations, including importing keystores, running validators, and signing exits when required.

  - The validator state is stored in `/opt/validator/data`.

- **Prometheus Metrics (`prometheus`)**:

  - Prometheus monitors the health and performance of Charon and the validator clients. It collects metrics and sends them to an external monitoring URL if specified.

  - The configuration for Prometheus is handled through templates, and the monitoring targets are defined dynamically based on the active Charon clusters.

### Configuration

- **Setup Wizard**: The package includes a setup wizard where users can configure up to five Charon clusters. During initial setup, ENR (Ethereum Node Record) information is generated for each Charon node, which is required to join a distributed validator cluster (DV).
- **Cluster Configuration**: The package supports two configuration modes:

  - **New Cluster / Simple Update**: Suitable for first-time setup or minor updates.
  - **File Upload or URL Import**: You can either upload node artifacts (e.g., `.tar.gz`, `.zip`) or provide a URL to a definition file for the Distributed Key Generation (DKG) ceremony.

  Only the `Definition File URL` is mandatory for starting the DKG process. All other fields are optional and can be left blank during setup if importing configuration via file or URL.

### Advanced config

- **P2P Ports**: To modify the default P2P ports, you will have to:

1. **Advanced Config**  
   Set these environment variables:
   - `CHARON_P2P_TCP_ADDRESS` → `0.0.0.0:<NEW_TCP_PORT>`
   - `CHARON_P2P_UDP_ADDRESS` → `0.0.0.0:<NEW_UDP_PORT>`

2. **Network** tab  
   Add the corresponding port mappings:
   - `<NEW_TCP_PORT>:<NEW_TCP_PORT>` (TCP)
   - `<NEW_UDP_PORT>:<NEW_UDP_PORT>` (UDP)
     > The env vars **must** match the published ports. If they differ, external peers won’t be able to reach your node.

### Script Integration

- **Staker Tools Integration**: The `dvt_lsd_tools.sh` script is sourced from the `staker-package-scripts` repository. It is downloaded during the Docker build process using the release version specified in the `STAKER_SCRIPTS_VERSION` argument. The script is placed in `/etc/profile.d/` to manage staking-related operations.

- **Cluster Initialization Scripts**:

  - `handle-file-import.sh`: Handles importing node artifacts into the Charon directory.
  - `run-charon.sh`: Starts the Charon middleware.
  - `run-validator.sh`: Starts the validator client (Lodestar).

  These scripts ensure proper configuration and synchronization between Charon and the validator.

### Backup and Restore

The package supports backup and restore functionality for each Charon cluster. You can back up critical data, such as the Charon configuration and validator data, from the Dappnode UI. This feature allows users to restore their DV setup in case of system failure or during migration to a new node.

- **Charon Config**: `/opt/charon/.charon` (for each cluster).
- **Validator Data**: `/opt/validator/data` (for each cluster).

### Monitoring

Prometheus monitors the health of each Charon node and the validator clients. Metrics are sent to a remote monitoring URL if provided during setup.

To configure which clusters to monitor, specify the `CHARONS_TO_MONITOR` variable as a comma-separated list of cluster numbers (e.g., "1,2,3"). The metrics are scraped every 30 seconds and sent to the configured monitoring URL.

---

For more detailed steps and documentation, please refer to the [Obol documentation](https://docs.obol.org).
