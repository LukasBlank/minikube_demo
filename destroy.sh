#!/bin/bash
minikube delete -p cluster-argo &
minikube delete -p cluster-satelite-1 &
minikube delete -p cluster-satelite-2 &
wait
read -rp "Press Enter to exit..."
