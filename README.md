<div align="center">
    <img alt="DAWN Logo" src="DAWN Logo.png" height=400>
</div>

## Introduction

*DAWN* (Daily Assessment of Warnings and Notifications) is a software system within the framework of [CRC393](https://www.uni-marburg.de/en/trr-393), a large-scale research initiative funded by the German Research Foundation (DFG) that focuses on affective disorders such as depression and bipolar disorder. These are mental health conditions that affect a person’s mood and emotions, often in serious and long-lasting ways. The goal is to understand how and why symptoms of these disorders change over time — why some people get better, others relapse, and some experience chronic problems. To this end, 1,500 people (both patients and healthy individuals) will be followed over two years and examined using mobile apps, brain scans, and biological samples to monitor changes in real life. An important goal is to detect upcoming manic and depressive episodes in real-time using adaptive sampling strategies, which allows patients to be examined, for example, using medical imaging techniques while the episode is developing.

And that's where DAWN comes into play: Every day early in the morning (during dawn, so to speak), it collects data from mobile apps (e-diaries from [InteractionDesigner](https://www.movisens.com/en/products/interactiondesigner/) and passive sensing data from [movisensXS](https://www.movisens.com/en/products/movisensxs/)) and analyzes them for the presence of early warning signals. Detected signals are forwarded to a research database, which in turn notifies staff at the study centers in Marburg, Münster and Dresden to contact the relevant patients. DAWN not only detects upcoming episodes (so-called inflection signals), but also, for example, remission of an episode, whether a patient is having problems with the mobile apps, or frequently fails to answer their e-diary questions. The data is currently being checked for a total of 18 different signals. In addition, DAWN provides feedback to staff on how many questionnaires patients have responded to and how many items they have completed in total.

## Setup

DAWN is deployed on a virtual machine. Currently, an Ubuntu 22.02 image is used via [bwCloud SCOPE](https://www.bw-cloud.org/en/). See [First Steps](https://www.bw-cloud.org/en/first_steps) for setup instructions. For fast and smooth operation, 8GB of RAM is recommended.

After creating the virtual machine, all packages should first be updated.

```terminal
sudo apt update
sudo apt upgrade
```

[Julia](https://julialang.org/) can then be installed with the following command.

```terminal
curl -fsSL https://install.julialang.org | sh
```

Additionally, this repository must be cloned.

```terminal
git clone https://github.com/CarlBittendorf/DAWN.git
```

To use the cloned repository, a `secrets.jl` file must be created inside the project directory that contains access data, API keys, etc.

```terminal
touch secrets.jl
nano secrets.jl
```

The following package manager commands must be executed from the project directory to install the required packages.

```julia
activate .
```

```julia
instantiate
```

Scripts can then be tested from the terminal, and the setup script must also be executed.

```terminal
cd /home/ubuntu/DAWN
```

```terminal
julia --project tests/email.jl
```

```terminal
julia --project scripts/setup.jl
```

To have the scripts run automatically at a specific time, a corresponding entry must be made in the crontab configuration file. This is opened or created with the following command.

```terminal
crontab -e
```

The following lines run the scripts daily at 5:30 am, 5:35 am, 5:40 am, 7:30 am, 7:35 am and 7:40 am respectively.

```plain
30 5 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/signals.jl 1'
35 5 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/signals.jl 2'
40 5 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/signals.jl 3'
30 7 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback.jl 1'
35 7 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback.jl 2'
40 7 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback.jl 3'
```

To update to the latest version of DAWN, run

```terminal
git pull
```

in the project directory.

## Acknowledgements

Funded by the Deutsche Forschungsgemeinschaft (DFG, German Research Foundation) – GRK2739/1 – Project Nr. 447089431 – Research Training Group: KD²School – Designing Adaptive Systems for Economic Decisions

Funded by the Deutsche Forschungsgemeinschaft (DFG, German Research Foundation) – CRC393 – Project Nr. 521379614 – Trajectories of Affective Disorders: Cognitive-emotional Mechanisms of Symptom Change