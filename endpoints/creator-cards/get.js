const { createHandler } = require('@app-core/server');
const { CreatorCardMessages } = require('@app/messages');
const getCreatorCard = require('@app/services/creator-cards/get');

module.exports = createHandler({
  path: '/creator-cards/:slug',
  method: 'get',
  middlewares: [],
  async handler(rc, helpers) {
    const { slug } = rc.params;
    const { access_code } = rc.query;
    const card = await getCreatorCard(slug, access_code);
    return {
      status: helpers.http_statuses.HTTP_200_OK,
      message: CreatorCardMessages.RETRIEVED,
      data: card,
    };
  },
});
