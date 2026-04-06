# Now

## SQS Bridge
The OBS bridge sucks, it's like a million files.  Figure out what the right shape is supposed to be, and make sure you update the OBS bridge to use it as well

## Twitch Chat Bridge (QA)

Publish Chat events as received from Twitch into the Event Pipeline

Consume Twitch Bridge Control events to turn the bridge on / off

Consume Twitch Chat events from the Event Pipeline to populate Redis with last N chat messages

Probably also keep a list of seen nicknames?

    redis.lpush("recent_twitch_chat", payload)
    redis.ltrim("recent_twitch_chat", 0, 5)

## Twitch Chat Renderer (QA)
Make a Hotwire-enabled screen to render chat as a web page with the thought to make a web source out of it later

We probably want to support twitch emoji and put at least a little thought into support the 7-whatever emoji's too

These will be important from the obs-bridge for the hotwire technique

[obs_bridges/show.html.erb](https://github.com/meleneth/orinoco/blob/158aebcbffdcd3546675be23ffa3dc0c62c76c9f/railsapp/app/views/admin/obs_bridges/show.html.erb#L46)
[obs_bridges/_status_panel.html.erb](https://github.com/meleneth/orinoco/blob/main/railsapp/app/views/admin/obs_bridges/_status_panel.html.erb)
[services/obs_bridge/status_broadcaster.rb](https://github.com/meleneth/orinoco/blob/158aebcbffdcd3546675be23ffa3dc0c62c76c9f/railsapp/app/services/obs_bridge/status_broadcaster.rb#L11)

# Soon

## Make a Discord Bridge
This might be difficult due to the need to securely store and access a secret

## figure out which twitch integration library to use - [http://rubygems.org](http://rubygems.org), search for twitch

## follow the Hotwire example to get an Overlay going
we use Hotwire currently for the OBS bridge control status panel

we will want to maintain a master list of events per-domain (i.e. obs, twitch, etc) so we can subscribe to them and also because we only want to let known event types pass

integrate the long-running processes that will be talking to twitch


# Later

## come up with an event configuration UI
What events in what domains we're subscribed to, and what events we want to send.

## trigger configuration UI
Streamer bot has it right that everything needs it's own configuration place, but lost the game in making the links be not-navigable

## event pipeline config
From the web page we'll want to be able to maintain what the pipeline looks like - what SNS queues are listening for events, and which SQS queues they publish the events to.  A lot of this should 'just work' because we're making things that require specific wiring, but we should be able to view the setup as well

## figure out if we care about multi user access
password sniffing is bad and encryption is tricky, but profiles is still a thing? devise ruby gem

## need a global kill switch for all the bridges in case the user doesn't want stuff running all the time
right now we can bring the one bridge we have up or down, but we need The Big Switch

# Done

## Integrate SNS / SQS via GoAWS (create the Event Pipeline)
The server is running, the OBS bridge is controllable (bridge up/down) and commandable (OBS commands).

[config/initializers/event_pipeline_config.rb](https://github.com/meleneth/orinoco/blob/158aebcbffdcd3546675be23ffa3dc0c62c76c9f/railsapp/config/initializers/event_pipeline_config.rb#L23)

## Create the OBS bridge
A long-running bridge process connects to OBS via obs-websocket and handles event-driven control of scenes and inputs. The event pipeline version is now functional, with a control queue to manage bridge lifecycle (start/stop) and a command queue for passing commands through to OBS.

The bridge can be started via:

    ./railsapp/bin/dev

or

    cd railsapp && ./dev.sh bridge


## be able to trigger clips to be able to play
Playback is triggered by sending events into the pipeline. The OBS bridge consumes these events and forwards them directly as obs-websocket requests (e.g., enabling the relevant scene item).

## be able to import clip names from an auto-discovered scene
Scene and input inventory is fetched from OBS and normalized into Redis, allowing ClipShow to enumerate available clip sources without manual configuration.


## make a Clipshow affordance for doing QA style clip management
The Clipshow affordance provides a purpose-built workflow for managing media clips in OBS scenes for QA-style operation. It is implemented using discovered OBS inventory data combined with event-driven control, allowing clips to be identified, triggered, and automatically cleaned up after playback.

There is currently no configuration UI. Running the following script seeds ClipShow for the `Clips` scene in OBS:

    ./r_dev runner script/dev/seed_clipshow.rb

## Let it be Known that the event pipeline is currently SNS/SQS, locally hosted via a goaws container

## get rails site running via docker and foreman for all devs
The development environment is split between Docker-managed services and local process orchestration.

`./dc_dev up -d` starts required infrastructure (Postgres, Redis, GoAWS).  
`./railsapp/bin/dev` runs the Rails webserver, Tailwind watcher, and OBS bridge.

    ./dc_dev up -d
    ./railsapp/bin/dev


## compose.yml to configure docker compose to run rails, goaws, opentelemetry, postgres
A unified Docker Compose setup defines the full local development stack, including Rails, GoAWS, OpenTelemetry, and Postgres. This provides a reproducible environment for all developers and mirrors the production topology at a smaller scale.


## install rbenv and ruby - instructions in devsetup.md
Development environment setup is standardized through documented steps for installing `rbenv` and the required Ruby version. This ensures consistent runtime behavior across contributors and avoids system Ruby drift.
