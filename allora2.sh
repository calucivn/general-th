#!/bin/bash

execute_with_prompt() {
    echo "Executing: $1"
    if eval "$1"; then
        echo "Command executed successfully."
    else
        echo "Error executing command: $1"
        exit 1
    fi
}

cd allora-chain/basic-coin-prediction-node

sudo docker run -it --entrypoint=bash -v $(pwd)/worker-data-1:/data alloranetwork/allora-inference-base:latest -c "mkdir -p /data/keys && (cd /data/keys && allora-keys)"
sudo docker run -it --entrypoint=bash -v $(pwd)/worker-data-2:/data alloranetwork/allora-inference-base:latest -c "mkdir -p /data/keys && (cd /data/keys && allora-keys)"
sudo docker run -it --entrypoint=bash -v $(pwd)/worker-data-7:/data alloranetwork/allora-inference-base:latest -c "mkdir -p /data/keys && (cd /data/keys && allora-keys)"
sudo docker run -it --entrypoint=bash -v $(pwd)/worker-data-10:/data alloranetwork/allora-inference-base:latest -c "mkdir -p /data/keys && (cd /data/keys && allora-keys)"
sudo docker run -it --entrypoint=bash -v $(pwd)/worker-data-11:/data alloranetwork/allora-inference-base:latest -c "mkdir -p /data/keys && (cd /data/keys && allora-keys)"

if [ -f docker-compose.yml ]; then
    rm docker-compose.yml
    echo "Removed existing docker-compose.yml file."
    echo
fi

read -p "Enter WALLET_SEED_PHRASE: " WALLET_SEED_PHRASE
echo

echo "Generating docker-compose.yml file..."
cat <<EOF > docker-compose.yml
version: '3'
services:
  inference:
    container_name: inference
    build:
      context: .
    command: python -u /app/app.py
    ports:
      - "8000:8000"
    networks:
      eth-model-local:
        aliases:
          - inference
        ipv4_address: 172.22.0.4
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/inference/ETH"]
      interval: 10s
      timeout: 10s
      retries: 12
    volumes:
      - ./inference-data:/app/data
    restart: always

  updater:
    container_name: updater-basic-eth-pred
    build: .
    environment:
      - INFERENCE_API_ADDRESS=http://inference:8000
    command: >
      sh -c "
      while true; do
        python -u /app/update_app.py;
        sleep 24h;
      done
      "
    depends_on:
      inference:
        condition: service_healthy
    networks:
      eth-model-local:
        aliases:
          - updater
        ipv4_address: 172.22.0.5
    restart: always
    deploy:
      resources:
        limits:
          cpus: '0.05'
          memory: 50M

  worker-1:
    container_name: worker-1
    environment:
      - INFERENCE_API_ADDRESS=http://inference:8000
      - HOME=/data
    build:
      context: .
      dockerfile: Dockerfile_b7s
    entrypoint:
      - "/bin/bash"
      - "-c"
      - |
        if [ ! -f /data/keys/priv.bin ]; then
          echo "Generating new private keys..."
          mkdir -p /data/keys
          cd /data/keys
          allora-keys
        fi
        allora-node --role=worker --peer-db=/data/peerdb --function-db=/data/function-db \
          --runtime-path=/app/runtime --runtime-cli=bls-runtime --workspace=/data/workspace \
          --private-key=/data/keys/priv.bin --log-level=debug --port=9011 \
          --boot-nodes=/dns/head-0-p2p.testnet-1.testnet.allora.network/tcp/32130/p2p/12D3KooWLBhsSucVVcyVCaM9pvK8E7tWBM9L19s7XQHqqejyqgEC,/dns/head-1-p2p.testnet-1.testnet.allora.network/tcp/32131/p2p/12D3KooWEUNWg7YHeeCtH88ju63RBfY5hbdv9hpv84ffEZpbJszt,/dns/head-2-p2p.testnet-1.testnet.allora.network/tcp/32132/p2p/12D3KooWATfUSo95wtZseHbogpckuFeSvpL4yks6XtvrjVHcCCXk \
          --topic=allora-topic-1-worker \
          --allora-chain-key-name=testkey \
          --allora-chain-restore-mnemonic='$WALLET_SEED_PHRASE' \
          --allora-node-rpc-address=https://allora-rpc.testnet-1.testnet.allora.network/ \
          --allora-chain-topic-id=1
    volumes:
      - ./worker-data-1:/data
    working_dir: /data
    depends_on:
      - inference
    networks:
      eth-model-local:
        aliases:
          - worker-1
        ipv4_address: 172.22.0.11
    restart: always
    deploy:
      resources:
        limits:
          cpus: '0.05'
          memory: 50M

  worker-2:
    container_name: worker-2
    environment:
      - INFERENCE_API_ADDRESS=http://inference:8000
      - HOME=/data
    build:
      context: .
      dockerfile: Dockerfile_b7s
    entrypoint:
      - "/bin/bash"
      - "-c"
      - |
        if [ ! -f /data/keys/priv.bin ]; then
          echo "Generating new private keys..."
          mkdir -p /data/keys
          cd /data/keys
          allora-keys
        fi
        allora-node --role=worker --peer-db=/data/peerdb --function-db=/data/function-db \
          --runtime-path=/app/runtime --runtime-cli=bls-runtime --workspace=/data/workspace \
          --private-key=/data/keys/priv.bin --log-level=debug --port=9012 \
          --boot-nodes=/dns/head-0-p2p.testnet-1.testnet.allora.network/tcp/32130/p2p/12D3KooWLBhsSucVVcyVCaM9pvK8E7tWBM9L19s7XQHqqejyqgEC,/dns/head-1-p2p.testnet-1.testnet.allora.network/tcp/32131/p2p/12D3KooWEUNWg7YHeeCtH88ju63RBfY5hbdv9hpv84ffEZpbJszt,/dns/head-2-p2p.testnet-1.testnet.allora.network/tcp/32132/p2p/12D3KooWATfUSo95wtZseHbogpckuFeSvpL4yks6XtvrjVHcCCXk \
          --topic=allora-topic-2-worker \
          --allora-chain-key-name=testkey \
          --allora-chain-restore-mnemonic='$WALLET_SEED_PHRASE' \
          --allora-node-rpc-address=https://allora-rpc.testnet-1.testnet.allora.network/ \
          --allora-chain-topic-id=2
    volumes:
      - ./worker-data-2:/data
    working_dir: /data
    depends_on:
      - inference
    networks:
      eth-model-local:
        aliases:
          - worker-2
        ipv4_address: 172.22.0.12
    restart: always
    deploy:
      resources:
        limits:
          cpus: '0.05'
          memory: 50M

  worker-7:
    container_name: worker-7
    environment:
      - INFERENCE_API_ADDRESS=http://inference:8000
      - HOME=/data
    build:
      context: .
      dockerfile: Dockerfile_b7s
    entrypoint:
      - "/bin/bash"
      - "-c"
      - |
        if [ ! -f /data/keys/priv.bin ]; then
          echo "Generating new private keys..."
          mkdir -p /data/keys
          cd /data/keys
          allora-keys
        fi
        allora-node --role=worker --peer-db=/data/peerdb --function-db=/data/function-db \
          --runtime-path=/app/runtime --runtime-cli=bls-runtime --workspace=/data/workspace \
          --private-key=/data/keys/priv.bin --log-level=debug --port=9017 \
          --boot-nodes=/dns/head-0-p2p.testnet-1.testnet.allora.network/tcp/32130/p2p/12D3KooWLBhsSucVVcyVCaM9pvK8E7tWBM9L19s7XQHqqejyqgEC,/dns/head-1-p2p.testnet-1.testnet.allora.network/tcp/32131/p2p/12D3KooWEUNWg7YHeeCtH88ju63RBfY5hbdv9hpv84ffEZpbJszt,/dns/head-2-p2p.testnet-1.testnet.allora.network/tcp/32132/p2p/12D3KooWATfUSo95wtZseHbogpckuFeSvpL4yks6XtvrjVHcCCXk \
          --topic=allora-topic-7-worker \
          --allora-chain-key-name=testkey \
          --allora-chain-restore-mnemonic='$WALLET_SEED_PHRASE' \
          --allora-node-rpc-address=https://allora-rpc.testnet-1.testnet.allora.network/ \
          --allora-chain-topic-id=7
    volumes:
      - ./worker-data-7:/data
    working_dir: /data
    depends_on:
      - inference
    networks:
      eth-model-local:
        aliases:
          - worker-7
        ipv4_address: 172.22.0.17
    restart: always
    deploy:
      resources:
        limits:
          cpus: '0.05'
          memory: 50M

  worker-10:
    container_name: worker-10
    environment:
      - INFERENCE_API_ADDRESS=http://inference:8000
      - HOME=/data
    build:
      context: .
      dockerfile: Dockerfile_b7s
    entrypoint:
      - "/bin/bash"
      - "-c"
      - |
        if [ ! -f /data/keys/priv.bin ]; then
          echo "Generating new private keys..."
          mkdir -p /data/keys
          cd /data/keys
          allora-keys
        fi
        allora-node --role=worker --peer-db=/data/peerdb --function-db=/data/function-db \
          --runtime-path=/app/runtime --runtime-cli=bls-runtime --workspace=/data/workspace \
          --private-key=/data/keys/priv.bin --log-level=debug --port=9020 \
          --boot-nodes=/dns/head-0-p2p.testnet-1.testnet.allora.network/tcp/32130/p2p/12D3KooWLBhsSucVVcyVCaM9pvK8E7tWBM9L19s7XQHqqejyqgEC,/dns/head-1-p2p.testnet-1.testnet.allora.network/tcp/32131/p2p/12D3KooWEUNWg7YHeeCtH88ju63RBfY5hbdv9hpv84ffEZpbJszt,/dns/head-2-p2p.testnet-1.testnet.allora.network/tcp/32132/p2p/12D3KooWATfUSo95wtZseHbogpckuFeSvpL4yks6XtvrjVHcCCXk \
          --topic=allora-topic-10-worker \
          --allora-chain-key-name=testkey \
          --allora-chain-restore-mnemonic='$WALLET_SEED_PHRASE' \
          --allora-node-rpc-address=https://allora-rpc.testnet-1.testnet.allora.network/ \
          --allora-chain-topic-id=10
    volumes:
      - ./worker-data-10:/data
    working_dir: /data
    depends_on:
      - inference
    networks:
      eth-model-local:
        aliases:
          - worker-10
        ipv4_address: 172.22.0.20
    restart: always
    deploy:
      resources:
        limits:
          cpus: '0.05'
          memory: 50M
          
  worker-11:
    container_name: worker-11
    environment:
      - INFERENCE_API_ADDRESS=http://inference:8000
      - HOME=/data
    build:
      context: .
      dockerfile: Dockerfile_b7s
    entrypoint:
      - "/bin/bash"
      - "-c"
      - |
        if [ ! -f /data/keys/priv.bin ]; then
          echo "Generating new private keys..."
          mkdir -p /data/keys
          cd /data/keys
          allora-keys
        fi
        allora-node --role=worker --peer-db=/data/peerdb --function-db=/data/function-db \
          --runtime-path=/app/runtime --runtime-cli=bls-runtime --workspace=/data/workspace \
          --private-key=/data/keys/priv.bin --log-level=debug --port=9021 \
          --boot-nodes=/dns/head-0-p2p.testnet-1.testnet.allora.network/tcp/32130/p2p/12D3KooWLBhsSucVVcyVCaM9pvK8E7tWBM9L19s7XQHqqejyqgEC,/dns/head-1-p2p.testnet-1.testnet.allora.network/tcp/32131/p2p/12D3KooWEUNWg7YHeeCtH88ju63RBfY5hbdv9hpv84ffEZpbJszt,/dns/head-2-p2p.testnet-1.testnet.allora.network/tcp/32132/p2p/12D3KooWATfUSo95wtZseHbogpckuFeSvpL4yks6XtvrjVHcCCXk \
          --topic=allora-topic-11-worker \
          --allora-chain-key-name=testkey \
          --allora-chain-restore-mnemonic='$WALLET_SEED_PHRASE' \
          --allora-node-rpc-address=https://allora-rpc.testnet-1.testnet.allora.network/ \
          --allora-chain-topic-id=11
    volumes:
      - ./worker-data-11:/data
    working_dir: /data
    depends_on:
      - inference
    networks:
      eth-model-local:
        aliases:
          - worker-11
        ipv4_address: 172.22.0.21
    restart: always
    deploy:
      resources:
        limits:
          cpus: '0.05'
          memory: 50M

networks:
  eth-model-local:
    driver: bridge
    ipam:
      config:
        - subnet: 172.22.0.0/24

volumes:
  inference-data:
  worker-data:


EOF

echo "docker-compose.yml file generated successfully!"
echo

echo "Building and starting Docker containers..."
docker-compose build
docker-compose up -d
echo

echo "Checking running Docker containers..."
docker ps
