# Declarations · RGESN 2024 · RGAA 4.1.2

69 criteria no rule can see from a page, declared by the service's owner for the whole record.
To answer, set yes, no, n/a or open after the criterion and a note after `//`, then run `releve declare`.
The official texts prevail: https://ecoresponsable.numerique.gouv.fr/publications/referentiel-general-ecoconception/ and https://accessibilite.numerique.gouv.fr/methode/criteres-et-tests/

## Strategy

- RGESN 1.1 · open · Has the service's usefulness been weighed against its environmental impact?
- RGESN 1.2 · open · Are the target users, business needs and user expectations defined?
- RGESN 1.3 · open · Is there a named eco-design lead?
- RGESN 1.4 · open · Is the eco-design approach reviewed regularly?
- RGESN 1.5 · open · Are there targets for reducing the service's own impact?
- RGESN 1.6 · open · Is data collected only as needed? · seen: 2 form fields
- RGESN 1.7 · open · Is encryption matched to need?
- RGESN 1.8 · open · Is the service open source where it can be?
- RGESN 1.9 · open · Is the service built on open, interoperable standards?
- RGESN 1.10 · open · Does the service use documented, open APIs to work with hardware?

## Specifications

- RGESN 2.1 · open · Are the supported device profiles listed?
- RGESN 2.2 · open · Does the service work on older devices? · seen: 5 requests, 532 kB, 33 elements
- RGESN 2.3 · open · Does the service work on a slow connection or offline? · seen: 5 requests, 532 kB, 33 elements
- RGESN 2.4 · open · Does the service work on older systems and browsers?
- RGESN 2.6 · open · Do design and code reviews include reducing each feature's impact?
- RGESN 2.7 · open · Is there a maintenance and decommissioning plan?
- RGESN 2.8 · open · Are suppliers required to reduce their impact?
- RGESN 2.9 · open · Was the impact of ready-made interface components weighed? · seen: no script
- RGESN 2.10 · open · Was the impact of third-party services weighed when choosing them? · seen: no third-party host

## Architecture

- RGESN 3.1 · open · Is the architecture designed to reduce its own impact?
- RGESN 3.2 · open · Do resources scale with actual use?
- RGESN 3.4 · open · Are corrective updates guaranteed for the planned life of devices and software?
- RGESN 3.5 · open · Can corrective updates be installed apart from feature updates?
- RGESN 3.6 · open · Are updates incremental?
- RGESN 3.7 · open · Are development, staging and test environments sized to need?

## Interface

- RGESN 4.3 · open · Is the path to each main feature as short as it can be?
- RGESN 4.5 · open · Are native components used for the most part?
- RGESN 4.6 · open · Does all video, audio and animation carry information? · seen: 1 audio or video elements
- RGESN 4.7 · open · Is the lightest format chosen among text, image, audio and video? · seen: 1 audio or video elements
- RGESN 4.9 · open · Are server requests limited while the user types? · seen: 2 form fields
- RGESN 4.10 · open · Is the expected input format shown before sending? · seen: 2 form fields
- RGESN 4.11 · open · Are expected file size and format shown before upload? · seen: no file upload on the page
- RGESN 4.12 · open · Are users told when a feature has a high environmental impact?
- RGESN 4.14 · open · Is the interface free of manipulative patterns?
- RGESN 4.15 · open · Can users track and reduce the impact of their own use?

## Content

- RGESN 5.2 · open · Is image compression matched to content and display? · seen: 3 images, 530 kB
- RGESN 5.3 · open · Is each video's resolution matched to content and display? · seen: 1 audio or video elements
- RGESN 5.4 · open · Is video compression efficient for content and display? · seen: 1 audio or video elements
- RGESN 5.5 · open · Do videos offer an audio-only mode? · seen: 1 audio or video elements
- RGESN 5.6 · open · Is audio compression matched to content and listening? · seen: 1 audio or video elements
- RGESN 5.7 · open · Is each document in a format suited to its use? · seen: no linked document on the page
- RGESN 5.8 · open · Is there a plan to archive or delete outdated content?

## Front end

- RGESN 6.1 · open · Is there a weight and request budget per screen? · seen: 5 requests, 532 kB, 33 elements

## Back end

- RGESN 7.1 · open · Is the most used data cached on the server?
- RGESN 7.2 · open · Are retention periods set for data and documents?
- RGESN 7.3 · open · Are users told when processing runs in the background?
- RGESN 7.4 · open · Does any consensus mechanism minimize its resource use?

## Hosting

- RGESN 8.1 · open · Does the host have a plan to reduce its footprint? · seen: localhost:8765
- RGESN 8.2 · open · Does the host manage its equipment sustainably? · seen: localhost:8765
- RGESN 8.3 · open · Is the host's PUE (power usage effectiveness) minimized? · seen: localhost:8765
- RGESN 8.4 · open · Is the host's WUE (water usage effectiveness) minimized? · seen: localhost:8765
- RGESN 8.5 · open · Is the host's electricity documented and mostly renewable? · seen: localhost:8765
- RGESN 8.6 · open · Is the hosting location consistent with the service's activity? · seen: localhost:8765
- RGESN 8.7 · open · Does the host put server heat to use? · seen: localhost:8765
- RGESN 8.8 · open · Are hot and cold data stored apart?
- RGESN 8.9 · open · Is data duplicated only where needed?
- RGESN 8.10 · open · Are deferred computations and transfers timed to reduce impact?

## Algorithms

- RGESN 9.1 · open · Was the need for model training questioned?
- RGESN 9.2 · open · Is model complexity proportionate to actual use?
- RGESN 9.3 · open · Is the amount of training kept down?
- RGESN 9.4 · open · Is training data limited to what is needed?
- RGESN 9.5 · open · Is retraining timed to need?
- RGESN 9.6 · open · Are models compressed?
- RGESN 9.7 · open · Is inference optimized for resources and users?

## Navigation across pages

- RGAA 12.1 · open · Does the site offer at least two ways to find a page: menu, search, or site map?
- RGAA 12.2 · open · Are the menu and navigation bars in the same place on every page?
- RGAA 12.3 · open · Does the site map list the site's pages and lead to them?
- RGAA 12.4 · open · Is the site map reached the same way from every page?
- RGAA 12.5 · open · Is the search reached the same way from every page?
