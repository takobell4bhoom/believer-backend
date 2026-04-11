import { pool } from '../src/db/pool.js';

const sampleMosques = [
  {
    name: 'Jamia Masjid Bengaluru',
    address_line: 'KR Market Road',
    city: 'Bengaluru',
    state: 'Karnataka',
    country: 'India',
    postal_code: '560002',
    latitude: 12.9635,
    longitude: 77.5736,
    facilities: ['parking', 'wudu', 'women_area'],
    is_verified: true,
    pageContent: {
      events: [
        {
          title: 'Family Fiqh Forum',
          schedule: 'This Sat',
          posterLabel: 'Family'
        },
        {
          title: 'Ramadan Volunteer Orientation',
          schedule: 'This week',
          posterLabel: 'Serve'
        }
      ],
      classes: [
        {
          title: 'Weekend Quran Reflection',
          schedule: 'Weekly',
          posterLabel: 'Quran'
        },
        {
          title: 'Teen Halaqa Circle',
          schedule: 'Sun 11 AM',
          posterLabel: 'Youth'
        }
      ],
      connect: [
        {
          type: 'instagram',
          label: 'instagram.com/jamiamasjidblr',
          value: 'instagram.com/jamiamasjidblr'
        },
        {
          type: 'facebook',
          label: 'facebook.com/jamiamasjidblr',
          value: 'facebook.com/jamiamasjidblr'
        }
      ]
    },
    broadcasts: [
      {
        title: 'Jummah Parking Update',
        description:
          'Overflow parking volunteers will guide arrivals from 12:15 PM this Friday. Please use the east gate when possible.',
        publishedAt: '2026-03-27T08:30:00.000Z'
      },
      {
        title: 'Weekend Quran Circle Registration',
        description:
          'Registration is open for the new weekend Quran circle for teens and working professionals.',
        publishedAt: '2026-03-24T09:15:00.000Z'
      }
    ]
  },
  {
    name: 'Masjid-e-Khadria',
    address_line: 'BTM Layout',
    city: 'Bengaluru',
    state: 'Karnataka',
    country: 'India',
    postal_code: '560076',
    latitude: 12.9166,
    longitude: 77.6101,
    facilities: ['wudu', 'quran_classes'],
    is_verified: true,
    pageContent: {
      events: [
        {
          title: 'Community Dinner for New Families',
          schedule: 'This Sat',
          posterLabel: 'Dinner'
        }
      ],
      classes: [
        {
          title: 'Beginner Tajweed Circle',
          schedule: 'Tue 7 PM',
          posterLabel: 'Tajweed'
        }
      ],
      connect: [
        {
          type: 'instagram',
          label: 'instagram.com/khadriaupdates',
          value: 'instagram.com/khadriaupdates'
        }
      ]
    },
    broadcasts: [
      {
        title: 'Community Dinner This Saturday',
        description:
          'Families are invited after Maghrib for a shared community dinner in the main hall.',
        publishedAt: '2026-03-26T12:00:00.000Z'
      }
    ]
  },
  {
    name: 'Tipu Sultan Mosque',
    address_line: 'Esplanade',
    city: 'Kolkata',
    state: 'West Bengal',
    country: 'India',
    postal_code: '700013',
    latitude: 22.5603,
    longitude: 88.3528,
    facilities: ['wudu', 'parking'],
    is_verified: true,
    broadcasts: []
  },
  {
    name: 'Nakhoda Masjid',
    address_line: 'Zakaria Street',
    city: 'Kolkata',
    state: 'West Bengal',
    country: 'India',
    postal_code: '700073',
    latitude: 22.5829,
    longitude: 88.3609,
    facilities: ['wudu', 'library'],
    is_verified: true,
    broadcasts: []
  },
  {
    name: 'Makkah Masjid',
    address_line: 'Charminar',
    city: 'Hyderabad',
    state: 'Telangana',
    country: 'India',
    postal_code: '500002',
    latitude: 17.3604,
    longitude: 78.4747,
    facilities: ['parking', 'wudu', 'women_area', 'wheelchair_access'],
    is_verified: true,
    broadcasts: [
      {
        title: 'Ramadan Volunteer Signups',
        description:
          'Volunteer slots for iftar setup and cleanup are now open at the front desk and online.',
        publishedAt: '2026-03-22T15:45:00.000Z'
      }
    ]
  }
];

async function run() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    for (const mosque of sampleMosques) {
      await client.query(
        `INSERT INTO mosques (
          name, address_line, city, state, country, postal_code,
          latitude, longitude, facilities, is_verified
        ) VALUES (
          $1, $2, $3, $4, $5, $6,
          $7, $8, $9::jsonb, $10
        )
        ON CONFLICT DO NOTHING`,
        [
          mosque.name,
          mosque.address_line,
          mosque.city,
          mosque.state,
          mosque.country,
          mosque.postal_code,
          mosque.latitude,
          mosque.longitude,
          JSON.stringify(mosque.facilities),
          mosque.is_verified
        ]
      );

      const mosqueResult = await client.query(
        `SELECT id
         FROM mosques
         WHERE name = $1 AND city = $2 AND address_line = $3`,
        [mosque.name, mosque.city, mosque.address_line]
      );
      const mosqueId = mosqueResult.rows[0]?.id;
      if (!mosqueId) {
        continue;
      }

      const pageContent = mosque.pageContent;
      if (pageContent) {
        await client.query(
          `INSERT INTO mosque_page_content (
             mosque_id,
             events,
             classes,
             connect_links
           ) VALUES ($1, $2::jsonb, $3::jsonb, $4::jsonb)
           ON CONFLICT (mosque_id) DO UPDATE SET
             events = EXCLUDED.events,
             classes = EXCLUDED.classes,
             connect_links = EXCLUDED.connect_links`,
          [
            mosqueId,
            JSON.stringify(pageContent.events ?? []),
            JSON.stringify(pageContent.classes ?? []),
            JSON.stringify(pageContent.connect ?? []),
          ]
        );
      }

      for (const broadcast of mosque.broadcasts) {
        await client.query(
          `INSERT INTO mosque_broadcast_messages (
             mosque_id,
             title,
             description,
             published_at
           ) VALUES ($1, $2, $3, $4)
           ON CONFLICT DO NOTHING`,
          [
            mosqueId,
            broadcast.title,
            broadcast.description,
            broadcast.publishedAt,
          ]
        );
      }
    }
    await client.query('COMMIT');
    console.log('Seed complete.');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Seed failed:', error);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
}

run();
