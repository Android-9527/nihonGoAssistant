import { createRouter, createWebHashHistory } from 'vue-router'
import { isLoggedIn } from '../store/user'
import HomePage from '../views/HomePage.vue'
import TextbooksPage from '../views/TextbooksPage.vue'
import TextbookChaptersPage from '../views/TextbookChaptersPage.vue'
import ChapterLearnPage from '../views/ChapterLearnPage.vue'
import MyWordsChapterPage from '../views/MyWordsChapterPage.vue'
import MyGrammarChapterPage from '../views/MyGrammarChapterPage.vue'
import WordsPage from '../views/WordsPage.vue'
import WordDetail from '../views/WordDetail.vue'
import SentencesPage from '../views/SentencesPage.vue'
import GrammarPage from '../views/GrammarPage.vue'
import GrammarDetail from '../views/GrammarDetail.vue'
import DonatePage from '../views/DonatePage.vue'
import AboutPage from '../views/AboutPage.vue'
import AboutProjectPage from '../views/AboutProjectPage.vue'
import AboutAuthorPage from '../views/AboutAuthorPage.vue'
import AboutChangelogPage from '../views/AboutChangelogPage.vue'
import LoginPage from '../views/LoginPage.vue'
import MePage from '../views/MePage.vue'
import TestPage from '../views/TestPage.vue'
import WordbookPage from '../views/WordbookPage.vue'
import WordbookSelectPage from '../views/WordbookSelectPage.vue'
import WordbookReviewPage from '../views/WordbookReviewPage.vue'
import PrivacyPage from '../views/PrivacyPage.vue'

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/', redirect: '/home' },
    { path: '/home', name: 'home', component: HomePage },
    { path: '/textbooks', name: 'textbooks', component: TextbooksPage },
    { path: '/textbook/:bookId/chapters', name: 'textbook-chapters', component: TextbookChaptersPage },
    { path: '/textbook/:bookId/chapter/:chapter/learn', name: 'chapter-learn', component: ChapterLearnPage },
    { path: '/my-words', name: 'my-words', component: MyWordsChapterPage },
    { path: '/my-grammar', name: 'my-grammar', component: MyGrammarChapterPage },
    { path: '/words', name: 'words', component: WordsPage },
    { path: '/word/:id', name: 'word-detail', component: WordDetail },
    { path: '/sentences', name: 'sentences', component: SentencesPage },
    { path: '/grammar', name: 'grammar', component: GrammarPage },
    { path: '/grammar/:id', name: 'grammar-detail', component: GrammarDetail },
    { path: '/donate', name: 'donate', component: DonatePage },
    { path: '/about', name: 'about', component: AboutPage },
    { path: '/about/project', name: 'about-project', component: AboutProjectPage },
    { path: '/about/author', name: 'about-author', component: AboutAuthorPage },
    { path: '/about/changelog', name: 'about-changelog', component: AboutChangelogPage },
    { path: '/login', name: 'login', component: LoginPage },
    { path: '/me', name: 'me', component: MePage, meta: { requiresAuth: true } },
    { path: '/test', name: 'test', component: TestPage, meta: { requiresAuth: true } },
    { path: '/wordbook', name: 'wordbook', component: WordbookPage, meta: { requiresAuth: true } },
    { path: '/wordbook/select', name: 'wordbook-select', component: WordbookSelectPage, meta: { requiresAuth: true } },
    { path: '/wordbook/review', name: 'wordbook-review', component: WordbookReviewPage, meta: { requiresAuth: true } },
    // 隐私政策：公开页面，无需登录（Google Play 要求可直接访问）
    { path: '/privacy', name: 'privacy', component: PrivacyPage },
  ],
})

router.beforeEach((to) => {
  if (to.meta && to.meta.requiresAuth && !isLoggedIn.value) {
    return { path: '/login', query: { redirect: to.fullPath } }
  }
  return true
})

export default router
