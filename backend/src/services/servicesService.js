import { pool } from '../db/pool.js';

const SERVICE_CATEGORY_CONFIG = [
  {
    canonical: 'Halal Food & Restaurants',
    groupAliases: ['Halal Food & Restaurants', 'Halal Food'],
    itemAliases: [
      'Catering Services',
      'Halal Butchers & Meat Shops',
      'Bakeries & Sweets',
      'Restaurants & Cafes',
      'Meal Delivery',
    ],
  },
  {
    canonical: 'Modest Fashion & Apparel',
    groupAliases: ['Modest Fashion & Apparel'],
    itemAliases: ["Women's Wear", "Men's Wear", 'Active Wear', 'Tailoring'],
  },
  {
    canonical: 'Education & Islamic Learning',
    groupAliases: ['Education & Islamic Learning'],
    itemAliases: ['Tutoring', 'Quran Classes', 'Arabic Learning', 'Islamic Schools'],
  },
  {
    canonical: 'Health & Wellness',
    groupAliases: ['Health & Wellness'],
    itemAliases: [
      'Medical Clinics',
      'Dental Clinics',
      'Therapists & Counselors',
      'Hijamah',
      'Nutritionists',
      'Dermatologists',
      'Dentists',
      'Gynecology Clinics',
      'Gym',
    ],
  },
  {
    canonical: 'Weddings & Events',
    groupAliases: ['Weddings & Events'],
    itemAliases: ['Nikah Planning', 'Event Styling', 'Event Catering', 'Event Photography'],
  },
  {
    canonical: 'Professional & Business Services',
    groupAliases: ['Professional & Business Services'],
    itemAliases: [
      'Legal Services',
      'Financial Advisors',
      'Real Estate Agents',
      'Business Consultants',
      'Insurance Agents',
    ],
  },
  {
    canonical: 'Home & Family Services',
    groupAliases: ['Home & Family Services'],
    itemAliases: [
      'Architecture',
      'Cleaning & Maintenance',
      'Handymen',
      'Movers & Packers',
      'Car Services',
    ],
  },
  {
    canonical: 'Creative & Art Services',
    groupAliases: ['Creative & Art Services'],
    itemAliases: [
      'Graphic Designers',
      'Developers',
      'Video Editors',
      'Content Creators',
      'Marketing',
      'Photography',
    ],
  },
  {
    canonical: 'Islamic E-commerce & Retail',
    groupAliases: ['Islamic E-commerce & Retail', 'Islamic Books'],
    itemAliases: [
      'Cosmetics & Skincare',
      'Books & Stationery',
      'Perfumes & Attar',
      'Home Decor',
      'Toys',
    ],
  },
  {
    canonical: 'Religious Services',
    groupAliases: ['Religious Services'],
    itemAliases: [
      'Nikah Officiants',
      'Quran Tutors',
      'Hajj & Umrah Support',
      'Community Speakers',
    ]
  },
];

function normalizeCategoryKey(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function buildCategoryConfig(entry) {
  const groupAliases = [...new Set(entry.groupAliases.map((value) => value.trim()))];
  const itemAliases = [...new Set(entry.itemAliases.map((value) => value.trim()))];
  const queryAliases = [...new Set([entry.canonical, ...groupAliases, ...itemAliases])];

  return {
    ...entry,
    queryAliases,
    groupAliasesNormalized: groupAliases.map(normalizeCategoryKey),
    itemAliasesNormalized: itemAliases.map(normalizeCategoryKey)
  };
}

const CATEGORY_CONFIGS = SERVICE_CATEGORY_CONFIG.map(buildCategoryConfig);

const CATEGORY_LOOKUP = new Map(
  CATEGORY_CONFIGS.flatMap((entry) =>
    entry.queryAliases.map((alias) => [normalizeCategoryKey(alias), entry.canonical])
  )
);

const CATEGORY_CONFIG_BY_CANONICAL = new Map(
  CATEGORY_CONFIGS.map((entry) => [entry.canonical, entry])
);

function toTitleCaseLabel(value) {
  return value
    .split(/\s+/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
    .join(' ');
}

function formatTimeOfDay(value) {
  if (!value || typeof value.hour !== 'number' || typeof value.minute !== 'number') {
    return null;
  }

  const hour = value.hour % 24;
  const minute = value.minute;
  const period = hour >= 12 ? 'PM' : 'AM';
  const displayHour = hour % 12 === 0 ? 12 : hour % 12;
  const displayMinute = String(minute).padStart(2, '0');
  return `${displayHour}:${displayMinute} ${period}`;
}

function buildHoursLabel(contactDetails) {
  if (contactDetails?.onlineOnly) {
    return 'Online only';
  }

  const opening = formatTimeOfDay(contactDetails?.openingTime);
  const closing = formatTimeOfDay(contactDetails?.closingTime);
  if (opening && closing) {
    return `${opening} to ${closing}`;
  }

  return 'Hours unavailable';
}

function buildLocation(contactDetails) {
  if (contactDetails?.onlineOnly) {
    return 'Online business';
  }

  const parts = [contactDetails?.city].filter((value) => typeof value === 'string' && value.trim().length > 0);
  if (!parts.length) {
    return 'Location unavailable';
  }

  return parts.join(', ');
}

function buildAddressLine2(contactDetails) {
  const parts = [contactDetails?.city, contactDetails?.zipCode]
    .filter((value) => typeof value === 'string' && value.trim().length > 0);
  return parts.join(', ');
}

function readStoredCategoryLabels(listing) {
  const selectedType = listing.basic_details?.selectedType;

  return {
    groupLabel:
      listing.category_group_label?.trim() || selectedType?.groupLabel?.trim() || null,
    itemLabel:
      listing.category_item_label?.trim() || selectedType?.itemLabel?.trim() || null
  };
}

function buildServicesOffered(listing) {
  const { groupLabel, itemLabel } = readStoredCategoryLabels(listing);

  return [itemLabel, groupLabel]
    .filter(Boolean)
    .map((label) => `${label} - Listed on Believers Lens`);
}

function resolveCanonicalCategory(category) {
  return CATEGORY_LOOKUP.get(normalizeCategoryKey(category)) ?? null;
}

function resolveCanonicalCategoryFromListing(selectedType = {}) {
  const groupLabel = selectedType.groupLabel?.trim();
  const itemLabel = selectedType.itemLabel?.trim();

  return resolveCanonicalCategory(itemLabel) ?? resolveCanonicalCategory(groupLabel);
}

function mapBusinessListingToService(listing) {
  const basicDetails = listing.basic_details ?? {};
  const contactDetails = listing.contact_details ?? {};
  const { groupLabel, itemLabel } = readStoredCategoryLabels(listing);
  const categoryLabel =
    resolveCanonicalCategory(itemLabel) ??
    resolveCanonicalCategory(groupLabel) ??
    resolveCanonicalCategoryFromListing(basicDetails.selectedType ?? {}) ??
    groupLabel ??
    'Community Services';
  const tags = [groupLabel, categoryLabel, itemLabel].filter(Boolean);

  return {
    id: listing.id,
    category: categoryLabel,
    name: basicDetails.businessName?.trim() || 'Business listing',
    location: buildLocation(contactDetails),
    priceRange: '--',
    deliveryInfo: contactDetails.onlineOnly ? 'Online only' : 'Contact for availability',
    rating: Number(listing.average_rating ?? 0),
    addressLine1: contactDetails.address?.trim() || '',
    addressLine2: buildAddressLine2(contactDetails),
    phoneNumber: contactDetails.phone?.trim() || null,
    whatsappNumber: contactDetails.whatsapp?.trim() || null,
    instagramHandle: contactDetails.instagramUrl?.trim() || null,
    facebookPage: contactDetails.facebookUrl?.trim() || null,
    websiteUrl: contactDetails.websiteUrl?.trim() || null,
    description: basicDetails.description?.trim() || '',
    hoursLabel: buildHoursLabel(contactDetails),
    savedCount: 0,
    reviewCount: Number(listing.total_reviews ?? 0),
    tags: [...new Set(tags)],
    servicesOffered: buildServicesOffered(listing),
    specialties: basicDetails.tagline?.trim() ? [basicDetails.tagline.trim()] : [],
    logo: basicDetails.logo ?? null,
    publishedAt: listing.published_at ? new Date(listing.published_at).toISOString() : null,
    createdAt: listing.created_at ? new Date(listing.created_at).toISOString() : null
  };
}

function normalizeFilters(filters) {
  return filters.map((item) => item.trim().toLowerCase()).filter(Boolean);
}

function matchesFilters(service, filters) {
  if (!filters.length) return true;

  return filters.every((filter) => {
    switch (filter) {
      case 'budget friendly':
        return service.priceRange === '$';
      case 'top rated':
        return service.rating >= 4.7;
      case 'fast delivery':
        return /30-40 mins|pickup and delivery/i.test(service.deliveryInfo);
      default:
        return true;
    }
  });
}

function compareNewestFirst(left, right) {
  const leftPublishedAt = left.publishedAt ? Date.parse(left.publishedAt) : 0;
  const rightPublishedAt = right.publishedAt ? Date.parse(right.publishedAt) : 0;
  if (rightPublishedAt !== leftPublishedAt) {
    return rightPublishedAt - leftPublishedAt;
  }

  const leftCreatedAt = left.createdAt ? Date.parse(left.createdAt) : 0;
  const rightCreatedAt = right.createdAt ? Date.parse(right.createdAt) : 0;
  if (rightCreatedAt !== leftCreatedAt) {
    return rightCreatedAt - leftCreatedAt;
  }

  return left.name.localeCompare(right.name);
}

function sortServices(services, { filters, sort }) {
  if (sort === 'top_rated' || filters.includes('top rated')) {
    return [...services].sort((left, right) => {
      if (right.rating !== left.rating) {
        return right.rating - left.rating;
      }
      if (right.reviewCount !== left.reviewCount) {
        return right.reviewCount - left.reviewCount;
      }
      return compareNewestFirst(left, right);
    });
  }

  if (sort === 'popular') {
    return [...services].sort((left, right) => {
      if (right.reviewCount !== left.reviewCount) {
        return right.reviewCount - left.reviewCount;
      }
      if (right.rating !== left.rating) {
        return right.rating - left.rating;
      }
      return compareNewestFirst(left, right);
    });
  }

  if (filters.includes('budget friendly')) {
    return [...services].sort((left, right) => left.priceRange.length - right.priceRange.length);
  }

  return [...services].sort(compareNewestFirst);
}

async function fetchApprovedBusinessListingServices({ category }) {
  const canonicalCategory = resolveCanonicalCategory(category);
  const categoryConfig = canonicalCategory
    ? CATEGORY_CONFIG_BY_CANONICAL.get(canonicalCategory)
    : null;

  if (!categoryConfig) {
    return [];
  }

  const result = await pool.query(
    `SELECT
       bl.id,
       bl.basic_details,
       bl.contact_details,
       bl.category_group_label,
       bl.category_item_label,
       bl.published_at,
       bl.created_at,
       review_summary.average_rating,
       review_summary.total_reviews
     FROM business_listings bl
     LEFT JOIN LATERAL (
       SELECT
         ROUND(COALESCE(AVG(r.rating), 0)::numeric, 1)::double precision AS average_rating,
         COUNT(*)::int AS total_reviews
       FROM business_listing_reviews r
       WHERE r.business_listing_id = bl.id
     ) review_summary ON TRUE
     WHERE bl.status = 'live'
       AND (
         LOWER(
           COALESCE(
             NULLIF(TRIM(bl.category_group_label), ''),
             NULLIF(TRIM(bl.basic_details->'selectedType'->>'groupLabel'), '')
           )
         ) = ANY($1::text[])
         OR LOWER(
           COALESCE(
             NULLIF(TRIM(bl.category_item_label), ''),
             NULLIF(TRIM(bl.basic_details->'selectedType'->>'itemLabel'), '')
           )
         ) = ANY($2::text[])
       )
     ORDER BY bl.published_at DESC NULLS LAST, bl.created_at DESC`,
    [
      categoryConfig.groupAliasesNormalized,
      categoryConfig.itemAliasesNormalized
    ]
  );

  return result.rows.map(mapBusinessListingToService);
}

export async function fetchServices({ category, filters, sort = 'new' }) {
  const normalizedFilters = normalizeFilters(filters);
  const approvedBusinessListings = await fetchApprovedBusinessListingServices({
    category
  });
  const filtered = approvedBusinessListings.filter((service) =>
    matchesFilters(service, normalizedFilters)
  );
  const sorted = sortServices(filtered, {
    filters: normalizedFilters,
    sort
  });

  return sorted;
}

export function isKnownServiceCategory(category) {
  return resolveCanonicalCategory(category) != null;
}
