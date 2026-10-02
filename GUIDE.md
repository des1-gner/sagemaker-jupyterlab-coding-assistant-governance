# Disabling the SageMaker Studio JupyterLab Coding Assistant

A general guide to the integrated coding assistant that ships with Amazon SageMaker Studio JupyterLab (SageMaker Distribution image version 4.1 and later), what it is, how it works, and how to disable it for security and governance reasons.

This guide is written from public AWS documentation and the open source SageMaker Distribution image build. It is not specific to any customer or environment.

## Background

As of SageMaker Distribution (SMD) image version 4.1, JupyterLab in SageMaker Studio includes an integrated coding assistant delivered through the Agent Context Protocol (ACP). The Kiro coding assistant is pre-configured in the chat panel by default, and other ACP compatible assistants (for example Claude, Gemini, OpenCode) can be configured as well [1].

When the assistant runs, the space loads a set of SageMaker AI Skills (markdown guidance files) from a public AWS repository into the assistant's context, and these are stored in `.kiro/skills` and `.agent/skills` in the user's home directory [1][3]. On private JupyterLab spaces the following hidden directories and files are commonly created as part of this behaviour:

- `.kiro` and `.agent` — the pre-configured agent and the SageMaker AI Skills (`.kiro/skills`, `.agent/skills`)
- `.claude` — created when the Claude assistant is configured or used; `.claude/skills` is typically a set of symbolic links back into `.agent/skills`
- `untitled.chat` — a chat file saved by the JupyterLab chat panel

These are expected artifacts of the feature, not an indication of compromise. The behaviour comes with the newer SMD image rather than from anything the user installs. Shared spaces have the chat extensions disabled in the image, so these artifacts are generally seen on private spaces.

## Common security and governance questions

### 1. Is the coding assistant enabled by default?

On private JupyterLab spaces running SMD 4.1 or newer, the Kiro coding assistant is pre-configured in the chat panel by default, so it is available to users of those spaces without any action on their part [1]. The skills and default agent setup are applied to private spaces at space startup, per the open source image build [2]. The capability is scoped to the JupyterLab application on a per space basis, not a single account wide switch.

### 2. What underlying models are used?

The models are not AWS managed by default, and which model is used depends on the assistant the user selects. Nothing is configured to work instantly out of the box: both the default assistant and the optional assistants require the user to authenticate, and for some assistants to choose a backend, before anything functions.

- The default Kiro assistant requires the user to authenticate to a Kiro account the first time the chat panel is opened. The login options include Builder ID, Google, GitHub, and an organization sign in [1]. In that path requests are served by Kiro's own backend models rather than an AWS managed model in your account.
- For Claude and other optional ACP assistants, the user chooses the backend during that assistant's own login. Claude Code can be pointed at a provider of the user's choice, for example directly at Anthropic, at Amazon Bedrock, or at another cloud provider [1].

Because these are third party or separately managed assistant applications, what a user can access is determined by which option they authenticate with. The practical controls are which assistants you permit in the environment (see section 5) and, for the Bedrock backed path specifically, Amazon Bedrock model access and IAM permissions on the execution role.

### 3. How are permissions handled?

The assistant runs inside the JupyterLab application as the user. By default it only has the access the local user grants it, for example reading or writing files, and these permissions are configurable for this type of agent. Only if the user allows broader actions, such as running scripts, could it use the space's execution role, the same identity the notebooks already use. It does not introduce a separate elevated role.

On the model traffic, the execution role is only involved if the user chooses Amazon Bedrock as the backend. If the assistant is pointed directly at Anthropic or another provider, that traffic leaves through that provider's own credentials rather than the AWS execution role. When configuring the Bedrock backed path there are several options for how it authenticates (for example the role's current credentials, or an access key), so the exact identity used depends on how the user sets it up [1].

The SageMaker AI Skills themselves are static markdown guidance files loaded into the assistant's context, so they do not carry any role or permissions of their own [1][3].

Because the non Bedrock paths reach a provider directly over the internet, one potential control at this layer is restricting outbound network access, for example running the spaces without public internet access or blocking the provider endpoints.

### 4. How does the flow work, and what logging is available?

At a high level, a user's prompt goes to the selected ACP assistant, which can draw on the SageMaker AI Skills (the `SKILL.md` files in `.kiro/skills` and `.agent/skills`) and a small set of tools exposed to it. In the default SageMaker agent configuration the tools made available are read only notebook operations (for example reading the active notebook and its cells and listing open documents) rather than broad write access [2]. The context shared with the model is therefore what the user types plus whatever the assistant reads through those tools, within the JupyterLab application.

On auditing, the clearest signal is the Bedrock backed path: when an assistant is configured against Amazon Bedrock, the model invocations are made with the execution role and are visible through CloudTrail and Amazon Bedrock model invocation logging, which you can enable and route to CloudWatch Logs or S3 [4]. For the default Kiro path, and for any assistant pointed at a non AWS provider, the model calls go to that provider rather than to an AWS service in your account, so those specific calls are not captured as AWS CloudTrail events in your account.

### 5. How can the functionality be disabled?

There are a few levers, depending on how completely you want to turn it off.

**Lifecycle configuration (LCC) or custom image.** The most direct mechanism is a JupyterLab lifecycle configuration (or a custom image) that disables both the server side and the front end chat extensions and clears the skill and agent setup. A default LCC can be attached at the Domain and the User Profile level, which gives administrative, environment wide enforcement rather than relying on each user [5]. An example LCC is provided in this repository ([`lcc-disable-coding-assistant.sh`](./lcc-disable-coding-assistant.sh)); it removes the chat assistant UI and stops the `.agent`, `.kiro`, and `.claude` artifacts from being recreated.

**Network controls.** Because a user can point these assistants at almost any provider and doing so only takes a minute, blocking the outbound network paths to those providers is the most effective single step, for example running the spaces without public internet access. This is the most important control for a complete block.

**Installation controls.** If you do not want developers using these tools at all, then in addition to the LCC, preventing them from re downloading and re installing the assistant CLIs (after the LCC removes them) is a sensible complementary control.

**IAM for the Bedrock path.** For the Bedrock backed path specifically, you can deny `bedrock:InvokeModel` and `bedrock:InvokeModelWithResponseStream` on the relevant execution roles. This governs the Bedrock path only, not the other providers, which is why the network and installation controls matter more for a complete block.

There is no single one click Domain level toggle dedicated to this feature, which is why the LCC or custom image approach, combined with network controls, is the route for a consistent, administratively enforced control.

## Using the example LCC

1. Create a JupyterLab lifecycle configuration from [`lcc-disable-coding-assistant.sh`](./lcc-disable-coding-assistant.sh) [5]:

   ```bash
   aws sagemaker create-studio-lifecycle-config \
     --studio-lifecycle-config-name disable-coding-assistant \
     --studio-lifecycle-config-content "$(base64 -i lcc-disable-coding-assistant.sh | tr -d '\n')" \
     --studio-lifecycle-config-app-type JupyterLab
   ```

2. Attach the returned ARN to the Domain and/or User Profile JupyterLab app settings as a default lifecycle configuration so new spaces inherit it [5].

3. Launch a JupyterLab space with the LCC attached and confirm the chat panel is gone and the hidden directories are not recreated. The script writes debug lines tagged `[LCC-DISABLE-CA]` so you can confirm it ran in the space's CloudWatch logs.

> Note: an LCC that only disables the server side extensions is not sufficient. The chat UI also requires the front end lab extensions to be disabled, and the hidden directories are created by a startup step independent of the extension toggles. The example LCC addresses all of these.

## References

[1] Using a coding assistant to expedite your machine learning workflows — https://docs.aws.amazon.com/sagemaker/latest/dg/studio-updated-jl-coding-assistant.html

[2] AWS SageMaker Distribution (open source image build) — https://github.com/aws/sagemaker-distribution

[3] AWSLabs agent-plugins, SageMaker AI Skills — https://github.com/awslabs/agent-plugins/tree/main/plugins/sagemaker-ai/skills

[4] Monitor model invocation using CloudWatch Logs and Amazon S3 — https://docs.aws.amazon.com/bedrock/latest/userguide/model-invocation-logging.html

[5] Lifecycle configuration creation (JupyterLab) — https://docs.aws.amazon.com/sagemaker/latest/dg/jl-lcc-create.html

---

This guide is provided as is, for general informational purposes, and is not official AWS documentation. Validate any change in a non production environment before applying it broadly.
