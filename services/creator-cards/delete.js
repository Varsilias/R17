const validator = require('@app-core/validator');
const { throwAppError } = require('@app-core/errors');
const creatorCardRepository = require('@app/repository/creator-card');

const DELETE_SPEC = `root {
  creator_reference string<length:20>
}`;

const parsedDeleteSpec = validator.parse(DELETE_SPEC);

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

async function deleteCreatorCard(slug, data) {
  validator.validate(data, parsedDeleteSpec, { dontThrowErrors: true });

  const card = await creatorCardRepository.findOne({ query: { slug, deleted: null } });

  if (!card) {
    throwAppError('Creator card not found', 'NF01');
  }

  const deletedAt = Date.now();

  await creatorCardRepository.updateOne({
    query: { _id: card._id },
    updateValues: { deleted: deletedAt },
  });

  const deletedCard = await creatorCardRepository.findOne({ query: { _id: card._id } });

  return serializeCard(deletedCard);
}

module.exports = deleteCreatorCard;
