// The author's own photos (from ky.is), without people in them, all taken in late October or early November, so the
// site can show what October 31 looks like in the app.
export interface Photo {
	src: string
	date: string
	place: string
	alt: string
	width: number
	height: number
}

const photo = (file: string, date: string, width: number, height: number, place: string, alt: string): Photo => ({ src: `/photos/${file}.avif`, date, place, alt, width, height })

export const PHOTOS = {
	ferryHome: photo('ferry-home', '2021-10-31', 1000, 667, 'Kingston, WA', 'The sun setting over the water from the ferry home'),
	fungus: photo('fungus-condensation', '2021-10-30', 1000, 750, 'Sequim, WA', 'Condensation beading on a pale fungus'),
	autumnReflection: photo('autumn-reflection', '2019-11-02', 750, 1000, 'New York City, NY', 'Autumn trees reflected in a still pond'),
	iguana: photo('bushwick-iguana', '2019-11-02', 1000, 750, 'New York City, NY', 'A graffiti iguana painted across a Bushwick wall'),
	prospectPark: photo('prospect-park', '2019-11-02', 507, 1000, 'New York City, NY', 'A path through autumn trees in Prospect Park'),
	dusk1702: photo('1702', '2022-11-02', 1000, 562, 'Seattle, WA', 'Clouds glowing over the water at 5:02 pm'),
	dusk1731: photo('1731', '2022-11-02', 1000, 667, 'Seattle, WA', 'The last light over the water at 5:31 pm'),
	window: photo('from-my-window', '2023-10-29', 1000, 750, 'Seattle, WA', 'A big tree beside a house, seen from a window'),
	ringPool: photo('ring-pool', '2014-10-28', 1000, 750, 'Shiratani, Yakushima', 'Water pouring into a round pool worn into the rock'),
	beaconHill: photo('beacon-hill', '2019-10-28', 750, 1000, 'Boston, MA', 'A brick lane on Beacon Hill lit up at night'),
	brooklynBridge: photo('brooklyn-bridge', '2019-11-03', 1000, 749, 'New York City, NY', 'The skyline through the cables of the Brooklyn Bridge'),
	statenFerry: photo('staten-island-ferry', '2019-11-03', 1000, 750, 'New York City, NY', 'The harbor from the open back of the Staten Island ferry'),
	workingLights: photo('working-lights', '2019-11-03', 1000, 750, 'New York City, NY', 'Traffic lights and a one-way sign on a city street at night'),
	torookiFalls: photo('torooki-falls', '2014-10-27', 1000, 750, 'Yakushima, Japan', 'Torooki Falls pouring into a green pool'),
	doubleRainbow: photo('bellevue-double-rainbow', '2021-10-26', 1000, 600, 'Seattle, WA', 'A double rainbow over the water'),
	chickens: photo('chicken-pen', '2016-10-25', 1000, 750, 'Santa Barbara, CA', 'Two chickens peering through a wire pen'),
	saturnJupiter: photo('saturn-and-jupiter', '2020-10-25', 1000, 750, 'Sedona, AZ', 'Red rock silhouetted against an evening sky'),
	rockyMountain: photo('rocky-mountain-national-park', '2016-10-24', 1000, 750, 'Estes Park, CO', 'Snow-dusted tundra in Rocky Mountain National Park'),
	cat: photo('neighborhood-cat', '2016-11-07', 1000, 750, 'Santa Barbara, CA', 'A tabby cat stepping out of the shadows'),
	cathedralRock: photo('cathedral-rocks-calling', '2020-11-07', 1000, 689, 'Sedona, AZ', 'Yellow autumn trees below Cathedral Rock'),
	flatirons: photo('flatirons', '2016-10-21', 750, 1000, 'Boulder, CO', 'A Flatiron rock rising above the pines'),
} satisfies Record<string, Photo>

export const photoYear = (photo: Photo) => Number(photo.date.slice(0, 4))
