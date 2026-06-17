const { throwAppError } = require('@app-core/errors');
const creatorCardRepository = require('@app/repository/creator-card');

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
    created: card.created,
    updated: card.updated,
    deleted: card.deleted ?? null,
  };
}

async function getCreatorCard(slug, accessCode) {
  const card = await creatorCardRepository.findOne({ query: { slug, deleted: null } });

  if (!card) {
    throwAppError('Creator card not found', 'NF01');
  }

  if (card.status === 'draft') {
    throwAppError('Creator card not found', 'NF02');
  }

  if (card.access_type === 'private') {
    if (!accessCode) {
      throwAppError('This card is private. An access code is required', 'AC03');
    }
    if (accessCode !== card.access_code) {
      throwAppError('Invalid access code', 'AC04');
    }
  }

  return serializeCard(card);
}

module.exports = getCreatorCard;
