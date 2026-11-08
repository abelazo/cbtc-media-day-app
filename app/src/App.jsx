
import DocumentIdForm from './components/DocumentIdForm'
import { PORTFOLIO_URL } from './links'
import LanguageSwitcher from './i18n/LanguageSwitcher'
import { useI18n } from './i18n/I18nContext'
import './App.css'

function App() {
  const { t } = useI18n()

  return (
    <div className="App">
      <header>
        <LanguageSwitcher />
      </header>
      <img src="/cbtc_logo_150.png" alt="CBTC Logo" />
      <h1>CBTC Media Day 2026</h1>
      <div className="card">
        <DocumentIdForm />
      </div>
      <footer style={{ fontSize: '0.8em', opacity: 0.8 }}>
        {t('footer.photos')} Abel Guillén ·{' '}
        <a href={PORTFOLIO_URL} target="_blank" rel="noopener noreferrer" style={{ color: 'inherit' }}>
          https://abelazo.photography
        </a>
      </footer>
    </div>
  )
}

export default App
