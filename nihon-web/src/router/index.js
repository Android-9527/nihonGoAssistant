import { createRouter, createWebHistory } from 'vue-router'
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

const router = createRouter({
  history: createWebHistory(),
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
  ],
})

export default router
