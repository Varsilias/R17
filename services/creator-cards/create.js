const validator = require('@app-core/validator');
const { throwAppError } = require('@app-core/errors');
const creatorCardRepository = require('@app/repository/creator-card');

const CREATE_SPEC = `root {
  title string<minLength:3|maxLength:100>
  description? string<maxLength:500>
  slug? string<minLength:5|maxLength:50>
  creator_reference string<length:20>
  links[]? {
    title string<minLength:1|maxLength:100>
    url string<maxLength:200>
  }
  service_rates? {
    currency string(NGN|USD|GBP|GHS)
    rates[] {
      name string<minLength:3|maxLength:100>
      description? string<maxLength:250>
      amount number<min:1>
    }
  }
  status string(draft|published)
  access_type? string(public|private)
  access_code? string<length:6>
}`;

const parsedCreateSpec = validator.parse(CREATE_SPEC);

const SLUG_CHAR_REGEX = /^[a-zA-Z0-9\-_]+$/;
const ACCESS_CODE_REGEX = /^[a-zA-Z0-9]{6}$/;

function buildBaseSlug(title) {
  return title
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9\-_]/g, '');
}

function randomSuffix() {
  return Math.random().toString(36).slice(2, 8).padEnd(6, '0').slice(0, 6);
}

function serializeCard(card) {
  return {
    id: card._id,
    title: card.title,
    description: card.description ?? null,
    slug: card.slug,
    creator_reference: card.creator_reference,
    links: card.links || [],
    service_rates: card.service_rates ?? null,
    status: card.status,
    access_type: card.access_type,
    access_code: card.access_code ?? null,
    created: card.created,
    updated: card.updated,
    deleted: card.deleted ?? null,
  };
}

async function createCreatorCard(data) {
  const validated = validator.validate(data, parsedCreateSpec, { dontThrowErrors: true });

  const accessType = validated.access_type || 'public';

  if (accessType === 'private' && !validated.access_code) {
    throwAppError('access_code is required when access_type is private', 'AC01');
  }

  if (accessType !== 'private' && validated.access_code) {
    throwAppError('access_code can only be set on private cards', 'AC05');
  }

  if (validated.access_code && !ACCESS_CODE_REGEX.test(validated.access_code)) {
    throwAppError('access_code must be exactly 6 alphanumeric characters (letters and numbers only)', 'AC01');
  }

  if (validated.slug && !SLUG_CHAR_REGEX.test(validated.slug)) {
    throwAppError('slug may only contain letters, numbers, hyphens, and underscores', 'SPCL_VALIDATION');
  }

  if (validated.links && validated.links.length > 0) {
    for (const link of validated.links) {
      if (!link.url.startsWith('http://') && !link.url.startsWith('https://')) {
        throwAppError('Each link url must start with http:// or https://', 'SPCL_VALIDATION');
      }
    }
  }

  if (validated.service_rates) {
    for (const rate of validated.service_rates.rates) {
      if (!Number.isInteger(rate.amount) || rate.amount < 1) {
        throwAppError('service_rates.rates[].amount must be a positive integer', 'SPCL_VALIDATION');
      }
    }
  }

  let slug = validated.slug;

  if (slug) {
    const existing = await creatorCardRepository.findOne({ query: { slug } });
    if (existing) {
      throwAppError('Slug is already taken', 'SL02');
    }
  } else {
    const base = buildBaseSlug(validated.title);
    const needsSuffix = base.length < 5 || !!(await creatorCardRepository.findOne({ query: { slug: base } }));
    slug = needsSuffix ? `${base}-${randomSuffix()}`.slice(0, 50) : base;
  }

  const card = await creatorCardRepository.create({
    title: validated.title,
    description: validated.description ?? null,
    slug,
    creator_reference: validated.creator_reference,
    links: validated.links || [],
    service_rates: validated.service_rates ?? null,
    status: validated.status,
    access_type: accessType,
    access_code: accessType === 'private' ? validated.access_code : null,
    deleted: null,
  });

  return serializeCard(card);
}

module.exports = createCreatorCard;
