<div align="center">
    <img alt="DAWN Logo" src="DAWN Logo.svg" height=300>
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

The following lines run the update, signal and feedback scripts daily and the compliance scripts weekly.

```plain
30 5 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/update.jl 1'
35 5 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/update.jl 2'
40 5 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/update.jl 3'
45 5 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/signals.jl 1'
50 5 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/signals.jl 2'
55 5 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/signals.jl 3'
00 7 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback_S01.jl 1'
05 7 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback_S01.jl 2'
10 7 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback_S01.jl 3'
15 7 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback_B01.jl 1'
20 7 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback_B01.jl 2'
25 7 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback_B01.jl 3'
30 7 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback_C01.jl 1'
35 7 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback_C01.jl 2'
40 7 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback_C01.jl 3'
45 7 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback_B05.jl 1'
50 7 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback_B05.jl 2'
55 7 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback_B05.jl 3'
00 8 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback_C03.jl 1'
05 8 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback_C03.jl 2'
10 8 * * 0-6 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/feedback_C03.jl 3'
30 8 * * 1 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/compliance_table.jl 1'
35 8 * * 1 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/compliance_table.jl 2'
40 8 * * 1 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/compliance_table.jl 3'
00 9 * * 1 bash -l -c 'cd /home/ubuntu/DAWN && julia --project scripts/compliance_figure.jl'
```

To update to the latest version of DAWN, run

```terminal
git pull
```

in the project directory.

## Acknowledgements

Funded by the Deutsche Forschungsgemeinschaft (DFG, German Research Foundation) – GRK2739/1 – Project Nr. 447089431 – Research Training Group: KD²School – Designing Adaptive Systems for Economic Decisions

Funded by the Deutsche Forschungsgemeinschaft (DFG, German Research Foundation) – CRC393 – Project Nr. 521379614 – Trajectories of Affective Disorders: Cognitive-Emotional Mechanisms of Symptom Change