# NARRO
## AI-Accelerated Business Roadmap
### Launch in 3-4 Weeks with Claude Code
#### A Black IT Academy Meta Project

---

## EXECUTIVE SUMMARY

Narro is a **$5/month social media curation app** that delivers algorithm-free feeds from users' unlimited selected profiles. Built with AI-first development using Claude Code, we'll move from concept to launch in 3-4 weeks through focused 1.5-hour working sessions. This is a meta-learning project for Black IT Academy members to experience modern AI-assisted product development at startup speed.

### Product Specifications

- **Pricing:** $5/month for unlimited profiles (no free tier)
- **Platforms:** iOS App Store + Android Play Store + Web App
- **Authentication:** Email-based (one-time password, passkey, or saved password)
- **Tech Stack:** To be determined in Session 1 (web framework, mobile framework, database, deployment)

### Key Learning Objectives

- Master AI-assisted rapid development workflows
- Ship production software in weeks through focused sessions
- Learn complete business operations alongside development
- Build real portfolio projects with paying customers

---

## DEVELOPMENT APPROACH

**Working Session Structure:**
- Each session: 1.5 hours
- Several sessions per week (flexible scheduling)
- Sessions can be done solo or with team members
- Focus on one clear outcome per session

**Timeline:** 
- **20-24 working sessions** total (3-4 weeks at 2-3 sessions/day or 5-7 sessions/week)
- Sessions grouped into phases but can be reordered based on availability

---

## PHASE 1: TECHNICAL FOUNDATION
**Sessions 1-8 (Week 1-2)**

### Session 1: Complete System Architecture (1.5 hours)
**Goal:** Define entire technical ecosystem with Claude

**Activities:**
- Discuss requirements and constraints
- Evaluate tech stack options with Claude (web frameworks, mobile frameworks, databases)
- Make architecture decisions based on team skills and project needs
- Database schema design (users, profiles, feeds, subscriptions)
- Scraping strategy for social media platforms
- Authentication flow specification
- Mobile + Web architecture decisions

**Deliverable:** Architecture document with all tech decisions finalized

---

### Session 2: Project Scaffolding (1.5 hours)
**Goal:** Get all projects initialized and connected

**Activities:**
- Claude Code scaffolds web app (using framework chosen in Session 1)
- Claude Code scaffolds mobile app (using framework chosen in Session 1)
- Set up repository structure
- Initialize database (using solution chosen in Session 1)
- Basic CI/CD pipeline

**Deliverable:** Empty but runnable projects on localhost

---

### Session 3: Authentication System - Backend (1.5 hours)
**Goal:** Core auth system working

**Activities:**
- Email-based authentication implementation
- Magic link / one-time password system
- Passkey support setup
- Traditional password option
- Session management

**Deliverable:** Authentication API endpoints working

---

### Session 4: Authentication System - Frontend (1.5 hours)
**Goal:** Users can sign up and log in on web

**Activities:**
- Login/signup UI (web)
- Email verification flow
- Session persistence
- Basic user dashboard

**Deliverable:** Can create account and log in via web app

---

### Session 5: Authentication - Mobile (1.5 hours)
**Goal:** Auth working on iOS and Android

**Activities:**
- Implement auth screens in mobile framework
- Test on iOS simulator
- Test on Android emulator
- Handle platform-specific auth flows

**Deliverable:** Can create account and log in via mobile apps

---

### Session 6: Stripe Integration (1.5 hours)
**Goal:** Payment system working

**Activities:**
- Stripe account setup
- Subscription product creation ($5/month)
- Payment flow implementation
- Webhook handling for subscription events
- Basic subscription management UI

**Deliverable:** Users can subscribe and payment works

---

### Session 7: Database Schema & APIs (1.5 hours)
**Goal:** Core data models in place

**Activities:**
- User profiles table
- Social accounts table (stores followed profiles)
- Feed items table
- Subscription status tracking
- Basic CRUD APIs for profile management

**Deliverable:** Database structure complete, APIs testable

---

### Session 8: Profile Management UI (1.5 hours)
**Goal:** Users can add/remove social profiles

**Activities:**
- Search and add social profiles interface
- Display user's saved profiles
- Delete/manage profiles
- Works on web and mobile

**Deliverable:** Can search for and save social media profiles to follow

---

## PHASE 2: CORE FEATURES
**Sessions 9-12 (Week 2)**

### Session 9: Web Scraping Infrastructure (1.5 hours)
**Goal:** Build scraper framework that works across platforms

**Activities:**
- Set up scraping library/framework
- Build reusable scraper components
- Handle authentication/cookies if needed
- Rate limiting and retry logic
- Error handling for failed scrapes

**Deliverable:** Scraping infrastructure ready to use

---

### Session 10: Multi-Platform Scrapers (1.5 hours)
**Goal:** Can scrape posts from Twitter/X, LinkedIn, Instagram

**Activities:**
- Build scrapers for 2-3 major platforms
- Parse HTML/JSON to extract posts, images, links
- Normalize data into unified format
- Store scraped content in database
- Test with various profile types

**Deliverable:** Can scrape and store posts from multiple social platforms

---

### Session 11: Feed Aggregation Engine (1.5 hours)
**Goal:** Create unified feed from all sources

**Activities:**
- Combine posts from all platforms
- Chronological ordering
- Pagination logic
- Refresh mechanism
- Background job for scheduled scraping

**Deliverable:** Single unified feed showing content from all followed profiles

---

### Session 12: Feed Display (1.5 hours)
**Goal:** Beautiful feed interface on web and mobile

**Activities:**
- Feed UI design and implementation (web)
- Post cards with images, text, links
- Mobile feed UI
- Pull to refresh
- Platform indicators (Twitter, LinkedIn, Instagram icons)

**Deliverable:** Clean, usable feed on both web and mobile apps

---

## PHASE 3: TESTING & REFINEMENT
**Sessions 13-16 (Week 2-3)**

### Session 13: Polish & Bug Fixes (1.5 hours)
**Goal:** Everything works smoothly

**Activities:**
- Test all user flows end-to-end
- Fix critical bugs
- Improve error messages
- Loading states
- Empty states

**Deliverable:** Solid MVP ready for internal testing

---

### Session 14: Internal Testing & Feedback (1.5 hours)
**Goal:** Team tests and provides feedback

**Activities:**
- Black IT Academy members test the app
- Document all issues and suggestions
- Prioritize fixes
- Create issue list

**Deliverable:** Comprehensive feedback document

---

### Session 15: Critical Bug Fixes & UX Improvements (1.5 hours)
**Goal:** Fix major issues and polish UX

**Activities:**
- Address breaking bugs
- Fix auth issues
- Fix payment flow problems
- Improve navigation flow
- Better onboarding
- UI refinements

**Deliverable:** All critical bugs resolved, app feels polished

---

### Session 16: Final QA Pass (1.5 hours)
**Goal:** Verify everything works

**Activities:**
- Team retests everything
- Verify bug fixes
- Test edge cases
- Performance check
- Final approval for launch prep

**Deliverable:** Confidence in product quality

---

## PHASE 4: LAUNCH PREPARATION
**Sessions 17-21 (Week 3)**

### Session 17: Production Infrastructure (1.5 hours)
**Goal:** Production environment ready

**Activities:**
- Production database setup with backups
- Deploy web app to hosting platform
- Environment variables configured
- Error monitoring (Sentry)
- Analytics setup (PostHog or Mixpanel)

**Deliverable:** Production infrastructure live and monitored

---

### Session 18: Legal Documents (1.5 hours)
**Goal:** Terms and policies in place

**Activities:**
- Use Claude to draft Terms of Service
- Draft Privacy Policy
- Cookie policy
- Add to website footer
- Compliance check

**Deliverable:** Legal documents published

---

### Session 19: App Store Submissions (1.5 hours)
**Goal:** Apps submitted for review

**Activities:**
- Create iOS App Store listing (screenshots, description)
- Create Google Play Store listing
- Submit iOS app for review
- Submit Android app for review
- TestFlight setup for beta testing

**Deliverable:** Apps in review, web app live

---

### Session 20: Marketing Assets & Landing Page (1.5 hours)
**Goal:** Marketing presence ready

**Activities:**
- Landing page with value proposition
- Demo video or screenshots
- Social media accounts setup
- Product Hunt draft
- Launch announcement prepared

**Deliverable:** Ready to market the product

---

### Session 21: Business Formation (1.5 hours)
**Goal:** Legal business entity created

**Activities:**
- LLC formation online (30 minutes)
- Business bank account application
- EIN registration
- Basic bookkeeping setup

**Deliverable:** Legitimate business entity

---

## PHASE 5: LAUNCH
**Sessions 22-24 (Week 3-4)**

### Session 22: Soft Launch (1.5 hours)
**Goal:** First real users

**Activities:**
- Private launch to Black IT Academy network
- Personal network outreach
- Monitor for critical issues
- Quick bug fixes if needed

**Deliverable:** First 10-20 paying customers

---

### Session 23: Public Launch - Product Hunt (1.5 hours)
**Goal:** Public visibility

**Activities:**
- Launch on Product Hunt
- Engage with comments
- Share on Twitter/LinkedIn
- Monitor signups and issues

**Deliverable:** Public presence, traffic spike

---

### Session 24: Post-Launch Stabilization (1.5 hours)
**Goal:** Handle launch issues

**Activities:**
- Fix any bugs from real usage
- Respond to user feedback
- Monitor server load
- Customer support responses

**Deliverable:** Stable product with real customers

---

## PHASE 6: GROWTH & ITERATION
**Ongoing sessions after launch**

### Growth Working Sessions (ongoing)

**Marketing & Content (1.5 hours each):**
- Blog posts about social media productivity
- SEO optimization
- Community engagement
- Social media management
- Outreach to tech bloggers

**Feature Development (1.5 hours each):**
- Advanced filtering (keywords, content types)
- Feed organization (folders, tags)
- Additional platform integrations (YouTube, Threads, Bluesky)
- Export/save functionality
- Analytics dashboard

**Business Development (1.5 hours each):**
- Customer feedback analysis
- Metrics review and reporting
- B2B outreach
- Partnership discussions
- Team/Enterprise tier development

---

## FINANCIAL PROJECTIONS

### Launch Costs (First Month)
- Domain & hosting: $50
- Infrastructure (database, hosting): $100-200
- Apple Developer account: $99
- Google Play Developer account: $25
- Tools (monitoring, analytics): $50
- **Total Initial Investment: ~$300-400** (LLC can come later)

### Monthly Operating Costs
- Infrastructure: $100-300 (scales with users)
- API costs: $200-800 (Twitter, LinkedIn, Instagram)
- Tools & services: $100 (email, analytics, monitoring)
- Payment processing: 2.9% + $0.30 per transaction (Stripe)
- **Total Monthly: $400-1,200**

### Revenue Projections
- **Month 1:** 50 users × $5 = $250 MRR
- **Month 3:** 200 users × $5 = $1,000 MRR (break-even)
- **Month 6:** 500 users × $5 = $2,500 MRR
- **Month 12:** 1,500 users × $5 = $7,500 MRR ($90K ARR)

### Key Metrics to Track
- Monthly Recurring Revenue (MRR)
- Churn rate (target: <5% monthly)
- Customer Acquisition Cost (CAC) - keep under $15
- Lifetime Value (LTV) - target 12+ month retention
- Daily Active Users (DAU) / Monthly Active Users (MAU)
- Net Promoter Score (NPS)

---

## TEAM STRUCTURE

### Flexible Roles (3-6 active members)

**Product Owner / Claude Code Driver (1-2 people):**
- Lead working sessions
- Write requirements and user stories
- Prompt Claude Code for features
- Review and test generated code
- Make technical decisions

**QA / Testing (1-2 people):**
- Test features across devices
- Document bugs and edge cases
- User acceptance testing
- Can participate in any session to test

**Business Operations (1 person):**
- Handle legal and financial setup
- Monitor metrics and finances
- Customer support coordination
- Can work async between dev sessions

**Marketing & Growth (1-2 people):**
- Create marketing content
- Social media management
- Community engagement
- Launch coordination

### Weekly Coordination

**Monday: Planning (30 min)**
- Review last week's progress
- Schedule this week's working sessions
- Prioritize what to tackle next

**Friday: Demo (30 min)**
- Demo completed work
- Celebrate wins
- Discuss what's next

**Ad-hoc:** Team members join working sessions when available

---

## RISK MANAGEMENT

### Technical Risks

**API Rate Limits:**
- **Risk:** Social platforms restrict API access
- **Mitigation:** Start with public APIs, build web scraping fallback, focus on 2-3 platforms initially

**App Store Rejection:**
- **Risk:** Apple/Google rejects app in review
- **Mitigation:** Web app launches regardless, follow guidelines strictly, have web-first mindset

**Claude Code Over-Reliance:**
- **Risk:** Team doesn't understand generated code
- **Mitigation:** At least one team member must fully understand each component, mandatory code reviews

### Business Risks

**Low Initial Adoption:**
- **Risk:** Can't get first 100 paying users
- **Mitigation:** Black IT Academy network provides initial users, keep costs low, iterate based on feedback

**Payment Processing Issues:**
- **Risk:** Stripe account issues or payment failures
- **Mitigation:** Have backup processor ready (Paddle), clear communication with customers

**Burnout / Inconsistent Sessions:**
- **Risk:** Team loses momentum, sessions don't happen
- **Mitigation:** Keep sessions short (1.5 hours), no pressure on frequency, celebrate small wins

---

## SUCCESS METRICS

### Development Milestones
- ✓ Session 8: Can add social profiles to follow
- ✓ Session 11: Feed aggregation working
- ✓ Session 13: MVP complete, internal testing begins
- ✓ Session 19: Apps submitted to stores, web app live
- ✓ Session 24: Public launch, first paying customers

### Business Milestones
- ✓ Week 4: 25+ paying customers ($125 MRR)
- ✓ Month 2: 100+ paying customers ($500 MRR)
- ✓ Month 3: Break-even (200+ customers, $1,000 MRR)
- ✓ Month 6: 500+ customers ($2,500 MRR)
- ✓ Month 12: 1,500+ customers ($7,500 MRR)

### Learning Milestones
- ✓ All team members understand AI-assisted development workflow
- ✓ 2+ members can independently prompt Claude Code for features
- ✓ Team collectively handles operations, support, and marketing
- ✓ Every active member has portfolio-ready work from Narro
- ✓ Team completes full product lifecycle in 3-4 weeks

---

## IMMEDIATE NEXT STEPS

### This Weekend
- [ ] Share this roadmap with potential team members
- [ ] Identify who wants to be Product Owner / Claude Code Driver
- [ ] Schedule Session 1 (Architecture) for early next week
- [ ] Purchase domain name

### Session 1 (Next Week)
- [ ] Complete system architecture with Claude
- [ ] Document all technical decisions
- [ ] Schedule next 5-7 sessions
- [ ] Get everyone on same page about the vision

### After First Few Sessions
- [ ] Sessions 2-8: Build core authentication and profile management
- [ ] Schedule regular check-ins (Monday planning, Friday demo)
- [ ] Keep momentum with 5-7 sessions per week
- [ ] Celebrate each completed session

---

## CONCLUSION

This is not a 6-month project. With AI-assisted development using Claude Code and focused 1.5-hour working sessions, Narro can go from concept to paying customers in **3-4 weeks** of part-time work.

The session-based approach means:
- **Flexible scheduling** - work when you have time
- **Clear outcomes** - each session has one goal
- **Sustainable pace** - 1.5 hours prevents burnout
- **AI acceleration** - Claude Code does the heavy lifting
- **Web scraping** - faster than API integrations, no approvals needed

For Black IT Academy members, this is a masterclass in rapid product development. You'll experience:

- Building production software through focused sessions
- Working with AI as a development accelerator
- Running a real business with actual paying customers
- Creating portfolio work that demonstrates modern development practices

Whether Narro becomes a sustainable business or a valuable learning experience, the journey of shipping a real product through ~24 working sessions will transform how you think about building software.

**Let's ship this thing.**
