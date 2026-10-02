# sagemaker-jupyterlab-coding-assistant-governance

A general guide and example lifecycle configuration (LCC) for disabling the integrated coding assistant (Kiro / ACP / SageMaker AI Skills) in Amazon SageMaker Studio JupyterLab on SageMaker Distribution image version 4.1 and later.

- [`GUIDE.md`](./GUIDE.md): background, common security and governance questions, and the disable options, with references.
- [`lcc-disable-coding-assistant.sh`](./lcc-disable-coding-assistant.sh): an example JupyterLab LCC that disables the chat assistant UI and stops the `.agent`, `.kiro`, and `.claude` artifacts from being recreated.

This is provided as is for general informational purposes and is not official AWS documentation. Validate any change in a non production environment before applying it broadly.
