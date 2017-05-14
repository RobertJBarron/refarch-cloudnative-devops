# DevOps & CSMO for Cloud Native Reference Application

*This project is part of the 'IBM Cloud Native Reference Architecture' suite, available at
https://github.com/ibm-cloud-architecture/refarch-cloudnative*

## Table of Contents
- **[Introduction](#introduction)**
- **[Architecture and CI/CD Workflow](#architecture-and-cicd-workflow)**
- **[Pre-Requisites](#pre-requisites)**
- **[Install and Setup Jenkins on Kubernetes](#install-and-setup-jenkins-on-kubernetes)**
- **[Create and Run a Sample CI/CD Pipeline](#create-and-run-a-sample-cicd-pipeline)**

## Introduction
DevOps, specifically Cloud Service Management & Operations (CSMO), is important for Cloud Native Microservice style applications. This project is developed to demonstrate how to use tools and services available on IBM Bluemix to implement CSMO for the BlueCompute reference application.

The full CSMO documentation is found at **[[TBD]]** 

This project deploys a self contained and independent monitoring stack into the Kubernetes Cluster. [**Helm**](https://github.com/kubernetes/helm) is Kubernetes's package manager, which facilitates deployment of prepackaged Kubernetes resources that are reusable. With the aid of Helm, the monitoring component **Prometheus** and the display component **Grafana** are deployed.

Let's get started.

## Architecture & CSMO toolchain
Here is the High Level DevOps Architecture Diagram for the CSMO setup on Kubernetes.

![DevOps Toolchain](static/imgs/architecture.png?raw=true)  

This guide will install the following resources:
* 3 x 20GB [Bluemix Kubernetes Persistent Volume Claim](https://console.ng.bluemix.net/docs/containers/cs_apps.html#cs_apps_volume_claim) to store Promethus and Grafana configuration and historical data.
* 1 x Grafana pod
* 3 x Prometheus pods
* 1 x Prometheus service for above Prometheus pods with only internal cluster IPs exposed.
* 1 x Grafana service for above Grafana pod with port 3000 exposed to an external LoadBalancer.
* All using Kubernetes Resources.

## Pre-Requisites
1. **CLIs for Bluemix, Kubernetes, Helm, JQ, and YAML:** Run the following script to install the CLIs:

    `$ ./install_cli.sh`

2. **Bluemix Account.**
    * Login to your Bluemix account or register for a new account [here](https://bluemix.net/registration).
    * Once you have logged in, create a new space for hosting the application in US-Southregions.
3. **Paid Kubernetes Cluster:** If you don't already have a paid Kubernetes Cluster in Bluemix, please go to the following links and follow the steps to create one.
    * [Log into the Bluemix Container Service](https://github.com/ibm-cloud-architecture/refarch-cloudnative-kubernetes#step-2-provision-a-kubernetes-cluster-on-ibm-bluemix-container-service).
    * [Create a paid Kubernetes Cluster](https://github.com/ibm-cloud-architecture/refarch-cloudnative-kubernetes#paid-cluster).

## Install Prometheus & Grafana on Kubernetes
### Step 1: Install Prometheus on Kubernetes Cluster
As mentioned in the [**Introduction Section**](#introduction), we will be using a Prometheus Helm Chart to deploy Prometheus into a Bluemix Kubernetes Cluster. Before you do so, make sure that you installed all the required CLIs as indicated in the [**Pre-Requisites**](#pre-requisites).

Here is a script that installs the Prometheus Chart for you:

    ```
    $ cd prometheus
    $ ./install_prometheus.sh <cluster-name> <Optional:bluemix-space-name> <Optional:bluemix-api-key>
    ```

The output of the above script will provide instructions on how to access the newly installed Grafana service.

**Note** that Prometheus and Grafana take a few minutes to initialize even after showing installation success

The `install_prometheus.sh` script does the following:
* **Log into Bluemix.**
* **Set Terminal Context to Kubernetes Cluster.**
* **Initialize Helm Client and Server (Tiller).**
* **Create Persistent Volume Claim,** which is where all Prometheus and Grafana related data is stored.
* **Install Prometheus Chart on Kubernetes Cluster using Helm.**
* **Install Grafana Chart on Kubernetes Cluster using Helm.**
* **Configure a Datasource in Grafana to access Prometheus.**

### Step 2: Import Prometheus specific dashboards to Grafana
This is a quick and easy way to see information in Grafana quickly and easily.

Here is the script that installs the Prometheus dashboards for you:

    ```
    $ cd prometheus
    $ ./import_dashboards.sh <grafana_ip> <admin_password>
    ```


That's it! You now have a fully working version of Prometheus and Grafana on your Kubernetes Deployment
