# **[KFP SDK](https://v1-5-branch.kubeflow.org/docs/components/pipelines/sdk/connect-api/) - Run Kubeflow pipelines directly from within the [Jupyter notebook](https://v1-8-branch.kubeflow.org/docs/components/notebooks/)**
To control Kubeflow Pipelines from the Jupyter notebook, a specific configuration file (manifest) is needed for each workspace (profile namespace) within Kubeflow. 

        kubectl apply -f access-ml-pipeline.yaml

        # verify
        kubectl get PodDefault -n <USER_PROFILE_NAMESPACE>

After applying the configuration file (manifest), during creating a new Jupyter notebook, an extra option in the configuration section (**_Allow access to Kubeflow Pipelines_**) need to be chosen to allow Jupyter notebook to interact with Kubeflow Pipelines.

With this configuration, then the Kubeflow Pipelines SDK client can be used directly within the Jupyter notebook without needing to specify extra arguments. The configuration takes care of the necessary details for the client to interact with Kubeflow Pipelines.

        import kfp
        client = kfp.Client()