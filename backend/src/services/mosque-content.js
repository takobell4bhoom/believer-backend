function normalizeString(value) {
  if (typeof value !== 'string') {
    return '';
  }

  return value.trim();
}

export function normalizeContentItems(items, fallbackPrefix) {
  if (!Array.isArray(items)) {
    return [];
  }

  return items
    .map((item, index) => {
      if (item == null || typeof item !== 'object') {
        return null;
      }

      const title = normalizeString(item.title);
      if (!title) {
        return null;
      }

      const schedule = normalizeString(item.schedule);
      const posterLabel = normalizeString(item.posterLabel);
      const id = normalizeString(item.id) || `${fallbackPrefix}-${index + 1}`;
      const location = normalizeString(item.location).slice(0, 120);
      const description = normalizeString(item.description).slice(0, 400);

      return {
        id,
        title,
        schedule,
        posterLabel,
        location,
        description
      };
    })
    .filter(Boolean)
    .slice(0, 12);
}

export function normalizeConnectLinks(items) {
  if (!Array.isArray(items)) {
    return [];
  }

  return items
    .map((item, index) => {
      if (item == null || typeof item !== 'object') {
        return null;
      }

      const type = normalizeString(item.type).toLowerCase() || 'other';
      const value = normalizeString(item.value);
      const label = normalizeString(item.label) || value;
      if (!value || !label) {
        return null;
      }

      return {
        id: normalizeString(item.id) || `connect-${index + 1}`,
        type,
        label,
        value
      };
    })
    .filter(Boolean)
    .slice(0, 12);
}

export function normalizeAboutContent(value) {
  if (value == null || typeof value !== 'object') {
    return null;
  }

  const title = normalizeString(value.title).slice(0, 120);
  const body = normalizeString(value.body).slice(0, 2000);
  if (!title && !body) {
    return null;
  }

  return { title, body };
}

function buildBaseConnectLinks(mosqueRow) {
  return [
    mosqueRow.contact_phone
      ? {
          id: 'contact-phone',
          type: 'phone',
          label: mosqueRow.contact_phone,
          value: mosqueRow.contact_phone
        }
      : null,
    mosqueRow.contact_email
      ? {
          id: 'contact-email',
          type: 'email',
          label: mosqueRow.contact_email,
          value: mosqueRow.contact_email
        }
      : null,
    mosqueRow.website_url
      ? {
          id: 'contact-website',
          type: 'website',
          label: mosqueRow.website_url,
          value: mosqueRow.website_url
        }
      : null
  ].filter(Boolean);
}

function dedupeConnectLinks(items) {
  const seen = new Set();

  return items.filter((item) => {
    const key = `${item.type}:${item.value.toLowerCase()}`;
    if (seen.has(key)) {
      return false;
    }

    seen.add(key);
    return true;
  });
}

export function mapMosquePageContent(row) {
  const storedEvents = normalizeContentItems(row?.events, 'event');
  const storedClasses = normalizeContentItems(row?.classes, 'class');
  const storedLinks = normalizeConnectLinks(row?.connect_links);
  const baseLinks = buildBaseConnectLinks(row ?? {});
  const about = normalizeAboutContent({
    title: row?.about_title,
    body: row?.about_body
  });

  return {
    events: storedEvents,
    classes: storedClasses,
    connect: dedupeConnectLinks([...baseLinks, ...storedLinks]).slice(0, 12),
    about
  };
}
