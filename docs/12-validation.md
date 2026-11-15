# 12. Validation of the working direction

Date: 15 November 2026. Task: PD.7.

**What was tested.** The working direction, not yet final: Phew teaches the software you work in, by pointing at the real interface when called, and then keeps collaborating on your projects like a normal AI assistant. First paid niche, later: B2B training on proprietary and legacy software that new workers must learn. Wider market: AI companions that collaborate inside projects. The claim "collaboration after learning stops people cancelling once they have learned" was tested as part of it.

**Method.** Four questions. For each one, a researcher searched the web and opened pages: forums, review sites, launch threads, surveys, price pages. Every quote carries a label:

- **user**: a person writing first-hand about their own experience.
- **summary**: a news article, a survey report or a study, written by someone else.
- **vendor**: a company that sells something in this market, or its own blog. Context only, not proof.

Then a second pass, the adversarial review, opened the same pages again. It checked that each quote is really on the page, attacked each claim, and searched for what the researcher missed. This report keeps only what survived. Quotes the review marked as misused are dropped. Claims the review refuted are listed in each section with the reason. New evidence found in review is added and marked "added in review".

**Limits. Read these before the verdict.**

- The biggest pools of first-hand opinion could not be read by either pass: Reddit, G2, Capterra, TrustRadius, the Mac App Store, the Autodesk forums, nurse forums. They refused to load.
- Most first-hand voices are developers, ERP administrators and hobby machinists on a few forums. No new office worker, nurse, bank clerk or government worker was heard.
- Quotes came through a fetch tool that returns short excerpts, about 125 characters. The review found every kept quote on its page, but a final check by hand is still needed before any quote is published outside this repository.
- Searches were in English and mostly about the United States. No Italian sources.
- The counts "for" and "against" count claims, not independent sources. Several claims rest on one to three people. Read the counts as rough.
- Desk research can show that a pain exists. It cannot show that people will pay or stay. Those two questions are still open after this report.

## 12.1 Verdict in one page

Scale used: supports / mixed / weakens / kills.

### Q1. Proprietary and legacy software training at work: WEAKENS

For the B2B legacy niche as first paid market, the review weakened it more than the researcher did.

Strongest points for:
1. The pain is real where it was sampled. In a KLAS survey of more than 35,000 physicians, 52% said their first training on the hospital record system was not enough. ERP users describe teaching themselves.
2. Buyers of today's guidance tools complain that walkthroughs are costly to build and break often. A tool that reads the live screen needs no authored walkthroughs.

Strongest points against:
1. Platform. Macs are about 11% of US enterprise PCs. Legacy software mostly runs on Windows or through Citrix, and Citrix ships a control that blocks AI screen capture, on Mac too. A Mac-only product cannot serve this niche as described.
2. The money that exists buys a different product: walkthroughs written centrally, deployed by IT, with reports for the employer. Nothing found shows that budget would move to a per-worker assistant. The buyer is IT or purchasing, not the worker who suffers.

### Q2. People learning everyday and pro apps: WEAKENS

Strongest points for:
1. Learners of Fusion, Excel and Figma say tutorials do not match the interface in front of them and that controls are hard to find.
2. Chat assistants do not know the current version of an app and can invent menu items. A pointing tutor is being sold at about $20 a month by the closest competitor, so that price is being tried in the market.

Strongest points against:
1. No user was found who pays, or says they would pay, for a pointing tutor. None was found refusing either. Willingness to pay is unproven in both directions.
2. Free substitutes are everywhere: free video is the default way to learn, a free screen-sharing chat assistant already talks users through spreadsheet tasks, and Windows bundles a pointing guide. Screen-seeing guidance also still makes mistakes, confirmed by two independent sources.

### Q3. AI companions that collaborate on projects: WEAKENS

Strongest points for:
1. Where pointing is praised, people name training and learning hard tools (3D, design). In one small lab study, guided "do it with me" beat full automation on control, learnability and accuracy.
2. Commenters on screen-aware tools ask for capture only when asked, not always on. That is Phew's design.

Strongest points against:
1. "Show me how" is under pressure from "do it for me". The one clear fan of the closest competitor also asked it to take actions. A large thread on screen pointing leans dismissive.
2. Nothing found shows that a tool first used for learning keeps being used for collaboration. Collaboration is exactly where general assistants, which people already pay for, are adding screen view, memory and projects.

### Q4. Privacy, always-watching tools and AI memory: MIXED

It supports the design choice. It weakens the B2B niche. It kills nothing.

Strongest points for:
1. Always-on screen recording is rejected loudly, and many of the same people say they want the function if it is local, encrypted and something they chose.
2. Always-on capture also costs heat and battery, which made users quit a Mac recorder. Looking only when called avoids that.

Strongest points against:
1. No evidence that anyone buys, pays more or stays because of "looks only when called, encrypted on the Mac". The dominant office suite now ships screen sharing that the user starts, on by default. Call-only is the normal shape now, not a difference.
2. In companies, a screen-reading tool from a small unknown vendor must pass a security review, while the incumbent's tool is already approved and already does the looking.

### Overall verdict on the direction: WEAKENS, does not kill

Nothing in the evidence kills the direction. Nothing proves it either. The pain is real and moderately supported. The payment and the retention are both unproven. The edge narrows to two things that only a test can show: pointing that is reliably right on the current version of the app, and privacy that can be shown, not just promised.

**(a) Teach the software you work in: MIXED.**
The need is supported at medium strength. The paid part is not supported and not refuted. Teaching looks like a way in for learners of hard tools, not a lasting position on its own.

**(b) Keep collaborating after learning, as the answer to churn: NOT SUPPORTED.**
Said plainly: no evidence was found either way. This part has not failed, because nothing tested it. But the plan cannot lean on it yet. Three hints point against it. A user described pointing help as something needed "when I was learning", in the past tense. An ERP user says the learning pain passes "after a few months". And collaboration is the ground where general assistants are strongest. It stays a hypothesis until interviews or a usage test say otherwise.

**(c) B2B proprietary and legacy software training as first paid niche: FAILS as stated.**
Said plainly: with a Mac-only product, this niche does not work as described. The software runs on Windows and Citrix, IT can block screen capture, the budget found buys a different product, and free lookalikes plus a bundled Microsoft feature already exist. It can stay as a later option with its own research, which is what the owner already planned. It should not be named the first paid niche, and the $30,000 to $40,000 contract figures should not be counted as its market, until three things are answered: which legacy software actually runs on Macs and in which firms, whether IT will allow a screen-reading assistant, and what new workers outside developer forums say.

## 12.2 Q1. Proprietary and legacy software training at work

Question: do new workers and their employers suffer from learning proprietary, old or hard-to-use software? Who pays today to fix it, at what price, and what do buyers and end users complain about? Do small and mid-size firms buy this?

### Findings

1. **New workers report being left to teach themselves ERP software.** Side: for. Strength: medium, and thin (three quotes, two threads, one from 2021). The review notes that the same threads advise built-in help and the vendor's paid services, and that one employer does provide training.
   > Basically I am playing around and training myself. [user, 2021-01-22](https://epiusers.help/t/new-user/74781)

   > Yes, with the training you have (or have not) been given, you have not been given an opportunity to succeed. [user, 2021-01-22](https://epiusers.help/t/new-user/74781)

   > The biggest challenge is learning where SAP puts everything [user, 2026-08-05](https://www.epiusers.help/t/switching-from-epicor-to-sap-any-advice/136702.md)

   Note: the last quote is cut. The sentence continues "...and getting familiar with the T-Codes…". The speaker is an experienced ERP administrator changing systems, not a new worker.

2. **In hospitals, about half of doctors found their first training on the record system insufficient.** Side: for. Strength: medium, one sector (the researcher said strong; lowered in review). The same article says the top complaints are slow loading and slow login, not learnability, and the cure proposed is more hours of human onboarding.
   > KLAS stressed the importance of EHR training, with 52% of doctors believing their initial training was insufficient. [summary, 2025-08-06](https://www.techtarget.com/searchhealthit/news/366628533/KLAS-Training-and-governance-needed-to-address-EHR-burnout)

   > KLAS interviewed more than 35,000 physicians to measure their EHR satisfaction. [summary, 2025-08-06](https://www.techtarget.com/searchhealthit/news/366628533/KLAS-Training-and-governance-needed-to-address-EHR-burnout)

3. **A third of US workers say support during technology rollouts is inadequate.** Side: for. Strength: weak to medium. Two thirds do not say this. The survey is by Eagle Hill, a consulting firm that sells change-management work, so it is closer to a vendor source. It is about new technology in general, not legacy software.
   > Meanwhile, 43% of workers aged 58+ say they receive inadequate support during tech rollouts, compared to 33% overall. [summary from an interested firm, 2025-08-18](https://www.tradeandindustrydev.com/industry/technologyrd/worker-survey-finds-us-companies-falling-short-34849)

4. **Employers already pay tens of thousands of dollars a year for on-screen guidance tools.** Side: for, with a large caveat. Strength: strong that the spending exists, weak that it applies to Phew (see "refuted" below).
   > Median buyer pays $39,000 per year [summary, 2026](https://www.vendr.com/buyer-guides/walkme)

   > the median cost of a Whatfix contract is $31,950/year [summary, 2026-07-26](https://userpilot.com/blog/whatfix-pricing/)

   > Implementation services (20-30% of first year contract) [summary, 2026-11-03](https://www.costbench.com/software/digital-adoption-platform/walkme/hidden-costs/)

   Notes: the first quote is a chart heading, not a sentence, and the page gives no sample size. The second comes from a competitor repeating Vendr data.

5. **Buyers of the incumbent tools complain about build effort, need for consultants and instability.** Side: for. Strength: medium. These quotes were chosen by a competitor's blog. The same page shows overall ratings near 4.4 to 4.5 out of 5 and positive quotes.
   > We use a consultant to set up all of our WalkMe applications because we do not have the technical expertise to do so [summary, 2026-01-28](https://userguiding.com/blog/walkme-reviews)

   > We build something and one day it works, but fails the next. [summary, 2026-01-28](https://userguiding.com/blog/walkme-reviews)

   > Building things in Walkme sometimes became too technical, not super easy [summary, 2026-01-28](https://userguiding.com/blog/walkme-reviews)

6. **End users of an ERP with built-in WalkMe pop-ups call them a nuisance and trade tips on blocking them.** Side: against (against unasked guidance). Strength: strong. Two of the three posters also concede the pop-ups have a purpose.
   > I know they serve a purpose, but to someone already familiar with the system, they’re just a nuisance. [user, 2025-01-06](https://www.epiusers.help/t/what-is-this-personalize-homepage/122087)

   > I just want them to rein in the gratuitous popups as they are obnoxious and irrelevant. [user, 2025-01-06](https://www.epiusers.help/t/what-is-this-personalize-homepage/122087)

   > Surely there’s good information in those popups, but if it’s going to interrupt my work I’m going to manage it if I can. [user, 2025-01-06](https://www.epiusers.help/t/what-is-this-personalize-homepage/122087)

7. **Technical users are mostly hostile to guided product tours.** Side: against. Strength: medium. The audience is developers, which may overstate the dislike. The researcher's tally did not reproduce in review, so no count is given here.
   > I also personally hate those product tours, is there a way we can get on boarded without that? [user, 2026-08-05](https://hn.algolia.com/api/v1/search_by_date?query=%22product%20tours%22&tags=comment&hitsPerPage=30)

   > introducing product tours is usually a band-aid for deeper UX problems. [user, 2026-05-06](https://hn.algolia.com/api/v1/search_by_date?query=%22product%20tours%22&tags=comment&hitsPerPage=30)

   > The product tours really help. [user, 2023-07-24](https://hn.algolia.com/api/v1/search_by_date?query=%22product%20tours%22&tags=comment&hitsPerPage=30)

8. **Critics of tours ask for help that does not interrupt.** Side: mixed. Strength: weak to medium. The fit with "looks only when called" is plausible, not shown (see "refuted").
   > Visible is fine, interruptive is not. [user, 2026-05](https://hn.nuxt.dev/item/48028546)

   > if I need to learn how to use a complex feature, I can consult the help or do a web search for a how to. [user, 2026-05](https://hn.nuxt.dev/item/48028546)

   > if you're application is complex no amount of "good ux" can replace a good overview/tour [user, 2026-05](https://hn.nuxt.dev/item/48028546)

9. **Do small and mid-size firms buy guidance platforms? Unknown, not absent.** Side: mixed. Strength: weak, and the evidence conflicts. The researcher said "no evidence"; the review corrected this.
   > Buyers in this range commonly see annual contract values between $40,000 and $150,000 [summary, 2026](https://www.vendr.com/buyer-guides/walkme)

   > Most contracts include a minimum user count or annual contract value (ACV). [summary, 2026](https://www.vendr.com/buyer-guides/walkme)

   > Whatfix software is very important for our company to integrate, train and support both remote and in-office employees [user, 2023-07](https://softwarefinder.com/lms/whatfix)

   > I have not seen a return on investment, as some competitors are significantly cheaper. [user, no date given, added in review](https://www.peerspot.com/products/walkme-reviews)

   Added in review: PeerSpot lists WalkMe reviewers as Small Business 14, Midsize Enterprise 3, Large Enterprise 8. Size labels are self-reported and some reviewers may be consultants.

10. **Workers who already know a legacy system are fast on it. Training is mostly company process, not the screen.** Side: against. Strength: medium. It suggests the learning window per worker is short, and that part of what a new worker lacks is not on screen for an assistant to read.
    > the agents hated it because they had every step necessary to do quotes and such memorized [user, 2025](https://hn.nuxt.dev/item/43348379)

    > I've literally heard non-techie employees of a Fortune 100 company ask for their legacy green screen terminals back [user, 2025](https://hn.nuxt.dev/item/43348379)

    > Did they require training? Of course they did. [user, 2022-10-02](https://hn.algolia.com/api/v1/search?query=%22green%20screen%22%20training%20employees&tags=comment&hitsPerPage=30)

    Note: the first quote is about a web replacement of a legacy system, not about training.

    > After a few months you’ll catch yourself saying [user, 2026-08-05, added in review](https://www.epiusers.help/t/switching-from-epicor-to-sap-any-advice/136702.md)

    > Thursday we get our “basic training” [user, 2026-08-05, added in review](https://www.epiusers.help/t/switching-from-epicor-to-sap-any-advice/136702.md)

11. **The person who buys enterprise software is not the person who uses it.** Side: against. Strength: weak (one comment).
    > the purchaser of enterprise software is usually some IT department, purchasing department, or executive [user, 2025](https://hn.nuxt.dev/item/43348379)

12. **The largest incumbent announces AI that appears unasked across applications.** Side: mixed. Strength: weak, vendor claim. It is the opposite design to call-only, and a sign of what enterprise buyers are being sold. The page does not mention desktop apps.
    > The Action Bar makes AI contextual, proactive, and omnipresent across every application and workflow. [vendor, 2026-02-23](https://www.walkme.com/blog/q1-26-release/)

    > It doesn't wait to be opened. [vendor, 2026-02-23, added in review](https://www.walkme.com/blog/q1-26-release/)

13. **Vendor data says guidance the user starts is finished more often than guidance pushed at them.** Side: mixed. Strength: weak, vendor figures. The date of the first page is unverified.
    > Click-triggered product tours have a 67% completion rate, the highest of any trigger type. [vendor, date unverified](https://www.chameleon.io/blog/mastering-product-tours)

    > 7+ steps? Only 16% make it to the end [vendor, date unverified](https://www.chameleon.io/blog/mastering-product-tours)

    > Popups are supposed to help users, but usually annoy them. [vendor, 2024-05-28](https://userobsession.substack.com/p/are-we-crazy-from-digital-adoption)

14. **Macs are about 11% of the US enterprise PC market.** Side: against. Added in review. This is the main problem for a Mac-only product in this niche.
    > The latest Omdia/Informa US PC market data found that Apple took an 11% share of the US enterprise market last year. [summary, reported April 2026](https://www.computerworld.com/article/4154950/apples-mac-grabs-11-of-us-enterprise-market-share.html)

15. **Citrix, a common way legacy and hospital software is delivered, can block screen capture by AI tools, on Mac too.** Side: against. Added in review.
    > App Protection helps safeguard sensitive information by detecting and blocking unauthorized screen capture attempts [vendor, no date given](https://docs.citrix.com/en-us/citrix-workspace-app/app-protection/app-protection-blocking-unauthorized-ai.html)

16. **Hospital record software on Mac is new and rare.** Side: against. Added in review.
    > Eleven-hospital Emory Healthcare is the first U.S. health system to use Epic on the Mac at scale. [summary, about 2024](https://www.hcinnovationgroup.com/clinical-it/electronic-health-record-electronic-medical-record-ehr-emr/news/53098701/emory-healthcare-first-to-use-epic-on-the-mac-at-scale)

17. **Near-identical products already exist: free on macOS, one on Windows, and Microsoft bundles one with Windows.** Side: against. Added in review. "No authoring needed" is no longer a unique opening.
    > Ourguide is Live for MacOS. [vendor, 2026-01](https://hn.algolia.com/api/v1/items/46769422)

    > an AI desktop assistant for Windows that sees your screen [vendor, listed June 2026](https://betalist.com/startups/guidy)

    > Sending many whole screenshots to an indie mystery box [user, 2026-01](https://hn.algolia.com/api/v1/items/46769422)

    > I wonder why we can't just make better UIs. [user, 2026-01](https://hn.algolia.com/api/v1/items/46769422)

18. **First-hand support for live guidance on the real screen.** Side: for. Added in review.
    > the biggest problem is ChatGPT doesn't have knowledge of Blender 5. [user, 2026-01](https://hn.algolia.com/api/v1/items/46769422)

    > I like how it actually shows an image of your screen and where to place your cursor. [user, 2026-01](https://hn.algolia.com/api/v1/items/46769422)

### Counts

Researcher: 5 for, 4 against, rest mixed. The review says to treat this as rough: it mixes strong, weak and vendor items. After the review's new evidence, the "against" side is heavier, and its heaviest item (platform) was not in the researcher's count at all.

### Prices seen

- WalkMe: median $39,000 a year, range $14,400 to $197,118 (Vendr, 2026, no sample size).
- WalkMe by size (Vendr): 100 to 500 users $40,000 to $150,000 a year; 500 to 1,500 users $120,000 to $400,000; 1,500+ users $350,000 to $800,000+.
- WalkMe: about $15 to $35 per user per month at 500 users; renewals rise 5 to 10% a year (Vendr).
- WalkMe: median $43,828 a year from 58 companies; implementation services 20 to 30% of the first-year contract (CostBench, 3 November 2026).
- Whatfix: median $31,950 a year, range $26,210 to $37,914 (Vendr data, repeated by Userpilot). List price is custom quote only.
- Tango: Free; Pro $22 a month; Enterprise custom (Toolradar, 14 November 2026).
- From search results only, pages not opened: Scribe Pro Team about $23 per seat per month from 5 seats; Userlane about $18,000 a year on average; Pendo median about $48,500 a year.

### What the reviewer refuted

- **"No evidence that small or mid-size firms buy these platforms."** Refuted in review as too absolute. Reviewer-size data on PeerSpot points the other way, weakly. A search snippet (page not opened) says 61% of Whatfix's 77 Capterra reviewers are small businesses. Fair statement: weak and conflicting evidence.
- **"Every price signal is enterprise."** Refuted in review. The Vendr page contradicts itself: the median ($39,000) and the low end ($14,400) are both below the floor of its "small" tier. Smaller deals exist. Vendr data also skews large, because it only covers firms that use a paid procurement service.
- **"The largest incumbent already ships screen-aware AI across applications."** Half right. It is a vendor claim, with no mention of desktop apps, and it describes a proactive design. The real competition risk is the direct lookalikes and Microsoft's bundled feature, which the researcher missed.
- **KLAS survey rated "strong".** Lowered to medium. Doctors on a modern record system are not new workers on old in-house software.
- **Eagle Hill survey labelled as a neutral summary.** It comes from a firm with an interest.
- **"New workers are left to teach themselves" (three quotes).** Thin. The same evidence equally supports "the pain is short and the fix people reach for is human training".
- **The Hacker News tally on product tours.** Did not reproduce. Direction is the same (mostly hostile). No count is published.
- **"Looks only when called matches what critics of tours ask for."** A stretch. The commenter says he would consult the help or search the web. That is not a request for an AI that reads the screen. Also, in the B2B niche a brand-new worker often does not know what to ask, which is why incumbents sell proactive guidance.
- **Mac versus Windows and Citrix left "not tested".** It can be tested, and the result hurts. See findings 14 to 16.
- **"Employers pay $30,000 to $40,000 a year, so the need and the budget exist."** The budget exists for a different product. One reviewer of the incumbent says "I have not seen a return on investment", so even the existing spend is contested.

### What was not searched

- G2, Capterra, Software Advice, GetApp, TrustRadius: refused to load (403). Gartner Peer Insights not opened directly.
- Reddit (r/SAP, r/sysadmin, r/Banking, r/nursing), allnurses.com, nurse.org, Becker's Hospital Review, The Financial Brand, the midrange.com archive, KLAS's own pages: not read.
- Banking core systems, logistics, CAD/PLM and government systems: no first-hand worker evidence found by either pass.
- Share of guidance-platform buyers by company size: no source found.
- Any independent controlled study of guided walkthrough versus no guidance: none found.
- Userlane, Pendo and Scribe pricing pages; Microsoft Copilot Vision reviews: seen in search results only.
- Churn after learning, for firms or workers: no evidence either way. A search snippet (not opened) offered only an analogy: meal-kit customers leave once they learn to cook.

## 12.3 Q2. People learning everyday and pro apps

Question: do learners of Figma, Excel, Autodesk Fusion and simple apps ask for step-by-step help inside the app? What do they use and pay now? Would they pay for an in-app pointing tutor? Do AI assistants give wrong click-by-click steps?

### Findings

1. **Learners say video tutorials do not match the current interface.** Side: for. Strength: medium. Most Fusion posts are from 2019 to 2020 and from hobby machinists, not the target user.
   > the YouTube videos all had a slightly different user interface than the current one [user, 2020-01-14](https://homemodelenginemachinist.com/threads/fusion-360-for-a-beginner.31495/page-2)

   > there are tons of videos on you tube but most of them concern older versions of the software [user, 2019-08-21](https://homemodelenginemachinist.com/threads/fusion-360-for-a-beginner.31495/page-2)

   > Many of the commands explained in the videos or on the exercises are outdated, especially in the pivots section. [user, 2025-07-30](https://www.coursera.org/programs/learning-program-e9odo/learn/excel-basics-data-analysis-ibm/reviews?page=86)

2. **Users struggle to find controls inside pro apps.** Side: for. Strength: medium.
   > I really pissed off when I couldn’t find grid settings by 3 minutes of staring at the navigation. [user, 2025-04-28](https://forum.figma.com/share-your-feedback-26/ui3-feedback-3058/index39.html)

   > All of those cute little icons and menus mean something - if you already know what they mean. [user, 2020-01-18](https://homemodelenginemachinist.com/threads/fusion-360-for-a-beginner.31495/page-2)

   > I still struggle when things are a little more complex and I'm flying solo. [user, 2025-01-19](https://forum.onefinitycnc.com/t/how-did-you-learn-fusion/30471)

3. **A few learners ask directly for help inside the app or for seeing the clicks.** Side: for. Strength: weak (three posts). The poster of the first quote is 71 and cites memory.
   > I have an X 35 and am wondering if there is an AI program that will help with fusion 360 CAD and CAM [user, 2024-04-09](https://forum.onefinitycnc.com/t/ai-to-help-with-fusion-360-commands/26392)

   > What I criticize about video tutorials is that you don't see the clicked menus [user, 2024-10-22](https://www.renderhub.com/blog/poll-which-learning-format-do-you-prefer)

   > It would be nice to find an icon list or flow chart or something to have next to the computer to look things up. [user, 2020-01-18](https://homemodelenginemachinist.com/threads/fusion-360-for-a-beginner.31495/page-2)

4. **Chat assistants give wrong click-by-click steps: invented menu items, no knowledge of new releases.** Side: for. Strength: medium (the researcher said strong; lowered in review after one quote was dropped). Found for macOS apps and Blender. No first-hand case for Excel, Figma or Fusion.
   > inventing commands, menu items, or features that don't exist. [summary, 2026-01-09](https://macmost.com/why-ai-cant-replace-tech-help-yet.html)

   > the biggest problem is ChatGPT doesn't have knowledge of Blender 5. [user, 2026-01](https://hn.svelte.dev/item/46769422)

   Note: the first quote is the author's own summary, not a user report. Reader comments there are mixed; some use chat assistants for tech questions for speed.

5. **Copilot in Excel disappoints paying users on accuracy and value.** Side: mixed. Strength: medium. It leaves a gap, and it also shows that users distrust AI help in these apps.
   > It cost too much and it has less abilities as the others have. [user, 2026-11-07](https://techcommunity.microsoft.com/discussions/microsoft365copilot/microsofts-copilot-a-frustrating-flop-in-ai-powered-productivity/4221190)

   > the facts it returns are frequently wrong. [summary, 2026-03-16](https://office-watch.com/2026/copilot-function-excel-accuracy-errors/)

6. **Some paying Copilot users want the task done, not explained.** Side: against. Strength: weak to medium (lowered in review). These are paying office workers using a product sold as doing the work, not beginners. It matters most for the later collaboration phase.
   > I can't perform the sorting directly for you, but I can guide you step-by-step [user, 2025-08-15](https://techcommunity.microsoft.com/discussions/microsoft365copilot/copilot-in-excel-performs-data-manipulation-once-and-then-refuses-all-subsequent/4444281)

   Note: this is Copilot's own reply, quoted by a user whose complaint is inconsistency (it did the task once, then refused).

   > il me répond qu'il ne peut pas le faire mais qu'il peut me dire comment je peux m'y prendre... [user, 2025-03-06](https://techcommunity.microsoft.com/discussions/microsoft365copilot/such-a-disappointment/4296967)

   In English, roughly: "it answers that it cannot do it but can tell me how to go about it".

   > often leaves you hanging with vague suggestions or instructions [user, 2024-08-16](https://techcommunity.microsoft.com/discussions/microsoft365copilot/microsofts-copilot-a-frustrating-flop-in-ai-powered-productivity/4221190)

7. **Free video is the default way to learn.** Side: against. Strength: medium (the researcher said strong; lowered in review). Some learners do pay and say paid is better.
   > All this basic information about in this course you can find on YouTube for free. [user, 2026-03-02](https://www.trustpilot.com/review/udemy.com?page=6)

   > 1157 people responded to this poll. [summary, 2024-09-29](https://www.renderhub.com/blog/poll-which-learning-format-do-you-prefer)

   Note: the poll measures preferred format (video 65%, written 24%, interactive courses 9%), not free against paid, and its audience is a 3D asset marketplace.

   > If you sign-up with Udemy, the classes are about 2 hours each and cost less than $20 each. [user, 2025-01-22, added in review](https://forum.onefinitycnc.com/t/how-did-you-learn-fusion/30471)

   Added in review: in the same thread one user calls paid Udemy classes "much better than YouTube options".

   > I'm starting to get more confident with every lesson. It's actually starting to make sense. [user, no date given, added in review](https://homemodelenginemachinist.com/threads/fusion-360-for-a-beginner.31495/page-2)

   Added in review: this is the same poster who complained about outdated interfaces, later reporting progress with free YouTube lessons.

8. **Pointing tutors launch with a free tier, and no commenter said they would pay.** Side: against, corrected in review. Strength: medium. The claim "every one is free" was false (see "refuted"). Paid tiers exist at about $20 a month. Nothing shows how many pay.
   > Live for MacOS and free to use. [vendor, 2026-01](https://hn.svelte.dev/item/46769422)

   > realistically how much would this cost to run for a typical 'show me how to do X'. [user, 2026-01](https://hn.svelte.dev/item/46769422)

   > Free to try. [vendor, 2026-05-06](https://hunted.space/product/spotit-3)

   > free forever, no card needed. [vendor, no date given, added in review](https://heyclicky.com)

   Added in review: the same site lists a free tier of 25 talk messages a month, Pro at $20 a month and Max at $100 a month.

9. **Reactions to pointing tutors are friendly but small and conditional.** Side: mixed. Strength: medium. Launches drew 120 to 135 upvotes and 6 to 9 comments.
   > If it works reliably, I could see it replacing static docs and videos! [user, 2026-01](https://hn.svelte.dev/item/46769422)

   > Before i try it, somehow I have i feeling that it would be too much of a distruction? or im too old 🫣 [user, 2026-04](https://www.hunted.space/product/clicky-2)

   > I wonder why we can't just make better UIs. [user, 2026-01](https://hn.svelte.dev/item/46769422)

10. **Screen capture triggers privacy questions in every launch thread.** Side: mixed. Strength: medium. One commenter asks for something close to the look-only-when-called design.
    > Sending many whole screenshots to an indie mystery box, though, should be a non-starter. [user, 2026-01](https://hn.svelte.dev/item/46769422)

    > The constant visibility is the double-edged sword here. I'd want a timed context window, not always-on capture. [user, 2026-04](https://www.hunted.space/product/clicky-2)

    > is it processing the screen locally or is my ui being sent to a server? [user, 2026-05](https://www.producthunt.com/products/spotit-3)

11. **A free built-in pointing guide ships on Windows, and screen-seeing guidance still gives wrong steps.** Side: against. Strength: medium. Accuracy reports are mixed, not uniformly bad.
    > instructed them to select 150 percent scaling - which was already the selected option. [summary, 2025-11-18](https://theoutpost.ai/news-story/microsoft-s-copilot-vision-falls-short-of-marketing-promises-in-real-world-testing-21776/)

    > Copilot Vision consistently failed to deliver accurate results or helpful assistance. [summary, 2025-11-18](https://theoutpost.ai/news-story/microsoft-s-copilot-vision-falls-short-of-marketing-promises-in-real-world-testing-21776/)

    Note: this page is an AI-written aggregator of two news articles. Weak as a source.

    > available for everyone via the Windows 11 Copilot app outside the United States (except EU regions) [summary, 2025-08-07](https://www.windowslatest.com/2025/08/07/windows-11s-built-in-copilot-vision-that-can-see-your-screen-now-works-for-free-everywhere-hands-on)

    > Copilot fumbled twice; first when it chose the wrong option to change text size [summary, 2025-11-19, added in review](https://www.windowslatest.com/2025/11/19/microsoft-yanks-copilot-ad-after-ai-fails-at-a-basic-windows-11-task-grandma-could-spot)

    > Vision was pretty accurate with it and even described what each parameter did in the commands. [summary, 2025-08-07, added in review](https://www.windowslatest.com/2025/08/07/windows-11s-built-in-copilot-vision-that-can-see-your-screen-now-works-for-free-everywhere-hands-on)

12. **A free screen-sharing chat assistant already walks users through spreadsheet tasks by voice.** Side: against (free substitute), with a point for the format. Added in review. A first-hand tester tried it on a pivot table.
    > It's free to use. [user, no date given](https://www.benlcollins.com/?p=21298)

    > It does make mistakes so you can't rely on it blindly. [user, no date given](https://www.benlcollins.com/?p=21298)

    > it's impressive and feels like you're talking to an assistant, not your computer. [user, no date given](https://www.benlcollins.com/?p=21298)

13. **AI apps win the first payment more often and keep it for less time.** Side: mixed (the researcher said against; corrected in review). Strength: medium. The data is mobile subscription apps, not Mac desktop tools.
    > was 21.1% for AI apps, compared with a higher 30.7% for non-AI apps. [summary, 2026-03-10](https://techcrunch.com/2026/03/10/ai-powered-apps-struggle-with-long-term-retention-new-report-shows)

    > 30% faster than non-AI apps, at the median. [summary, 2026-03-10](https://techcrunch.com/2026/03/10/ai-powered-apps-struggle-with-long-term-retention-new-report-shows)

    Note: the second quote is a fragment from the middle of a sentence.

    > AI apps convert users from trials to paid customers 52% better than non-AI apps (8.5% vs. 5.6% at the median) [summary, 2026-03-10, added in review](https://techcrunch.com/2026/03/10/ai-powered-apps-struggle-with-long-term-retention-new-report-shows)

14. **For simple apps (notes, reminders, calendar, browser), the only demand found is for older or less technical users, raised by relatives.** Side: mixed. Strength: weak. No ordinary user was found asking for a tutor for these apps.
    > I think you should try to target it towards the elderly. [user, 2026-01](https://hn.svelte.dev/item/46769422)

    > This is also something I often have to do to help my mom. [user, 2024](https://www.producthunt.com/posts/helpmee-ai)

15. **People who learn with AI often cannot apply what they learned.** Side: for (guidance inside the real app). Added in review. The survey is by a tutoring company: treat with care.
    > Yet more than half (57%) said they struggled to put what they learned into practice. [summary, 2026-10-01](https://fortune.com/2026/10/01/gen-z-ai-learning-struggle-to-apply-survey/)

16. **A retention vendor states that learning subscriptions are cancelled once the goal is reached.** Side: against. Added in review. It cites no data. Context only, but it is the only statement found on the learn-then-cancel risk.
    > Most people cancel a learning subscription once they finish the goal or fall behind on it. [vendor, no date given](https://churnkey.co/use-case/edtech)

17. **A camera-based AI tutor on the Mac App Store charges $24.99 a month but has too few ratings to show a score.** Side: mixed. Added in review. Prices exist; proof of buyers does not.
    > This app hasn't received enough ratings or reviews to display an overview. [vendor, no date given](https://apps.apple.com/app/knowable/id6763789090)

### Counts

Researcher: 4 for, 5 against. After the review's corrections: 4 for (2 of them weak or medium), 4 against, 5 mixed. The "against" side is mostly absence of proof plus free substitutes, not users rejecting the idea.

### Prices seen

- Microsoft 365 Personal with Copilot: $9.99 a month or $99.99 a year, up from $6.99 and $69.99 (February 2025). Family: $12.99 a month or $129.99 a year.
- Microsoft 365 Copilot Business: $21 per user per month from July 2026, up from $18. Copilot for infrequent users cited at $30 per user per month. Both from search results, pages not opened.
- Udemy Fusion classes: under $20 each (forum user, January 2025).
- Paid Excel courses about $30 to $200; a ChatGPT-for-Excel course $99 lifetime. Search results only.
- Copilot Vision with Highlights on Windows: free.
- Clicky: free tier of 25 talk messages a month; Pro $20 a month; Max $100 a month (its own site, found in review). The open-source version is free with your own API keys.
- Spotit: free to try, no paid tier shown. Ourguide: free on macOS.
- Helpmee AI: free tier of 30 minutes a month, paid tiers not priced on the page.
- A camera-based AI tutor on the Mac App Store (Knowable): $24.99 a month.
- Other Mac screen assistants, from search results only: about $8 to $20 a month (Hover $8, Vida $9.90, Attyn $15, Cluely Pro $20).

### What the reviewer refuted

- **Dropped quote: the Apple support thread.** The text is on the page, but the user is answering a human's screenshot in a thread about smart replies in Messages. It is not an AI giving wrong steps. Removed from finding 4, which drops from strong to medium.
- **Dropped quote: the Figma forum post "around half the time".** The text is on the page, but it is about AI design generation producing fake interfaces, not how-to help. Removed from finding 5. No user feedback on Figma's in-app how-to answers was found.
- **"Every pointing tutor is free or free to try."** Refuted in review. The main competitor sells $20 and $100 monthly tiers. Vendor price pages show what is charged, not that anyone pays.
- **"AI apps keep fewer subscribers" as a purely negative finding.** One-sided. The same article reports better trial conversion (8.5% against 5.6%), more revenue per payer ($18.92 against $13.59 a month) and better weekly retention. Relabelled mixed.
- **"Users want the task done, not a lesson."** Overread. See finding 6.
- **"The COPILOT() worksheet function was retired on 14 September 2026."** Not on the cited page, which describes the function as new and in use. Removed.
- **"Free learning is the norm", rated strong.** Lowered to medium. See finding 7.
- **"No built-in equivalent on macOS."** Incomplete. General assistants already do screen-aware guidance on the Mac: the ChatGPT desktop app has a screen context option in voice mode for paid plans (search result, not opened), and Google's screen-share mode in AI Studio is free. They talk and do not point. Pointing is the only clear gap left.

### What was not searched

- Reddit (r/excel, r/FigmaDesign, r/Fusion360, r/BambuLab): blocked. Autodesk community forums: 403.
- User feedback on Autodesk Assistant in Fusion, and on Figma's in-app how-to answers: none found.
- A first-hand thread about a chat assistant giving wrong Excel, Figma or Fusion menu steps: not found.
- Mac App Store reviews of screen tutors; G2 and Capterra; YouTube comments; X posts.
- Paid tiers of Spotit and Ourguide: unknown.
- Dia browser, Apple Notes, Reminders and Calendar learners: no first-hand posts found.
- Cancelling after learning: no cancellation survey or first-hand account found.

## 12.4 Q3. AI desktop companions that collaborate on projects

Question: what do users of screen-aware assistants love, and what makes them stop? Do they value project memory? Do they want to be shown how, or to have it done for them? Does a tool used first for learning keep being used afterwards?

### Findings

1. **A cursor companion that points and explains gets some early enthusiasm.** Side: for. Strength: weak. It rests on one user comment; the supporting comparison is a vendor blog. That same user also asks for actions (finding 2).
   > I've been using this quite a bit and love the concept! [user, about April 2026](https://www.producthunt.com/posts/clicky-2)

   > Clicky.so is the most enjoyable agent to use in this group. [vendor, 2026-05-06](https://www.mindstudio.ai/blog/poke-vs-clicky-vs-cluey-vs-co-work-consumer-agent-comparison)

2. **Users of a pointing companion quickly ask it to act for them.** Side: against. Strength: medium, raised by the review's new evidence.
   > is it able to control the mouse? That would elevate the abilities intensively. [user, about April 2026](https://www.producthunt.com/posts/clicky-2)

   > I'd love to give it the ability to actually take actions on my screen as well. [user, about April 2026, added in review](https://www.producthunt.com/posts/clicky-2)

   > Clicky is reactive by design. [vendor, 2026-05-06](https://www.mindstudio.ai/blog/poke-vs-clicky-vs-cluey-vs-co-work-consumer-agent-comparison)

   Note: the last quote is a fragment of "The problem is that Clicky is reactive by design."

3. **On a large thread about AI drawing arrows on the screen (421 points), dismissal outweighs praise. Where pointing is praised, people name training and learning hard tools.** Side: against for a general consumer habit, for the teaching wedge. Added in review. The review's rough tally was more negative or joking comments than positive ones; it is an estimate, not a count.
   > If some agent will do that for them, why bother looking at screen at all? [user, no date given](https://news.ycombinator.com/item?id=50018817)

   > SO the point of this is ... what exactly? [user, no date given](https://news.ycombinator.com/item?id=50018817)

   > Seems great for scammers targeting old people tbh [user, no date given](https://news.ycombinator.com/item?id=50018817)

   > This kind of baked-in interactivity could really help in a training or disability context. [user, no date given](https://news.ycombinator.com/item?id=50018817)

   > I think this would've been very handy to me a couple years ago when I was learning to use Blender [user, no date given](https://news.ycombinator.com/item?id=50018817)

   Note the past tense in the last quote: the need was at the learning stage.

4. **In a lab study (20 people, a spreadsheet tool and a design tool), guided "do it with me" beat full automation on control, learnability and accuracy.** Side: for. Strength: medium at most. The page is the study author's own blog about their own research prototype. It measures preference in one session, not what people pay for or keep using. The same page says full automation sometimes saved time on simple tasks.
   > GuidedCopilot consistently outperformed AutoCopilot in user control, software utility, and learnability [study author's own blog, 2025](https://xiaotiansu.github.io/blog/2025/guided)

   > It felt like LLM 1 [AutoCopilot] was doing it for me, which is a bit of a gamble… [user (study participant), 2025](https://xiaotiansu.github.io/blog/2025/guided)

5. **"Do it for me" agents are not yet winning in practice: slow, and users want to see what they do.** Side: for. Strength: medium. This is about agent quality today, which is improving.
   > However, all of this comes with one downside—it’s slow. [user, 2025-07-18](https://artificialcorner.com/p/my-honest-review-of-chatgpt-agent)

   > users want visibility into what AI agents are doing, but not to micromanage every step [summary, 2026-02-13](https://macdailynews.com/2026/02/13/apple-studies-what-real-users-expect-from-ai-agents/?noamp=mobile)

   > We found that users were generally impressed with these agents but faced significant usability challenges [summary, 2025-09-18](https://arxiv.org/abs/2509.14528)

   > users are risk-averse, and one bad autonomous action is enough to make someone uninstall. [vendor, 2026-05-06, added in review](https://www.mindstudio.ai/blog/poke-vs-clicky-vs-cluey-vs-co-work-consumer-agent-comparison)

6. **Handing work to AI harms learning of a new tool; asking for explanations preserves it.** Side: for. Added in review. A controlled trial from January 2026. The participants were developers learning a code library, and the study says nothing about willingness to pay.
   > AI use impairs conceptual understanding, code reading, and debugging abilities. [summary, 2026-01](https://arxiv.org/abs/2601.20245)

7. **In one experiment, most people asked AI for the answer, not for guidance.** Side: against. Strength: weak (the researcher said medium; lowered in review). The study is about fraction problems in maths, gives no sample size, and is not about software.
   > About 61 percent of AI users said they mainly asked the assistant for direct answers. [summary, 2026-04-18](https://the-decoder.com/just-ten-minutes-of-using-ai-as-an-answer-machine-can-measurably-erode-problem-solving-skills-new-study-finds/)

   > Another quarter used it for hints or explanations, and the rest didn't use it at all. [summary, 2026-04-18](https://the-decoder.com/just-ten-minutes-of-using-ai-as-an-answer-machine-can-measurably-erode-problem-solving-skills-new-study-finds/)

8. **Commenters on a screen-aware companion ask for capture that is not always on.** Side: for. Strength: medium at most: three comments in one thread.
   > The constant visibility is the double-edged sword here. I'd want a timed context window, not always-on capture. [user, about April 2026](https://www.producthunt.com/posts/clicky-2)

   > there must be a great security concern and privacy policy [user, about May 2026](https://www.producthunt.com/posts/clicky-2)

   > Before i try it, somehow I have i feeling that it would be too much of a distruction? [user, about April 2026](https://www.producthunt.com/posts/clicky-2)

9. **Project memory: wanted by some, switched off by others, and it breaks trust when it misfires.** Side: mixed. Strength: weak to medium (the researcher said strong, "the strongest signal found"; refuted in review). The first two quotes are from one person in a five-post thread where the only other poster is support staff.
   > This would allow ChatGPT to function as a stateful working partner, not just a stateless conversational tool. [user, 2026-04-17](https://community.openai.com/t/give-chatgpt-a-user-controlled-persistent-project-memory-rules-structured-state-so-it-can-behave-like-a-consistent-long-term-collaborator-instead-of-a-stateless-chat/1379164)

   > The big thing for me is keeping it user-visible and editable [user, 2026-04-23](https://community.openai.com/t/give-chatgpt-a-user-controlled-persistent-project-memory-rules-structured-state-so-it-can-behave-like-a-consistent-long-term-collaborator-instead-of-a-stateless-chat/1379164)

   > Memory or context is almost non existence. [user, 2026-10-27](https://uk.trustpilot.com/review/claude.ai?page=4)

   > With memory, anything from your past chats could affect the results in ways that are hard to predict. [user, no date given, added in review](https://every.to/also-true-for-humans/why-i-turned-off-chatgpt-s-memory)

   > the conversation can no longer be trusted as a foundation for the project. [user, August to October 2026, added in review](https://community.openai.com/t/chatgpt-recalls-saved-memory-but-fails-to-apply-it-and-invents-plausible-context-instead-of-verifying-history/1393739)

   > Months and months of conversations and now it can’t remember. [user, August to October 2026, added in review](https://community.openai.com/t/chatgpt-recalls-saved-memory-but-fails-to-apply-it-and-invents-plausible-context-instead-of-verifying-history/1393739)

10. **Memory only helps if it is accurate and can be found again.** Side: mixed. Strength: medium. The Littlebird reviewers skew to founders and beta testers, and no negative review exists on that page.
    > Sometimes it hallucinates details - mostly harmless, occasionally hilarious, but you need to stay sharp. [user, about March 2026](https://www.producthunt.com/products/littlebird/reviews)

    > The issue is not simply memory. The issue is access and retrieval. [user, 2026-06-15](https://community.openai.com/t/projects-are-containers-not-archives-large-projects-need-retrieval-not-just-memory/1383739)

    > Helped me keep my targets in view and recover ideas/incomplete projects [user, about June 2026](https://www.producthunt.com/products/littlebird/reviews)

11. **The cancel reasons people write down are price changes, usage limits, reliability and redesigns.** Side: mixed. Strength: medium. No review read said "I learned it, so I left". That neither proves nor disproves the churn worry. It shows other causes are louder.
    > It was good while it lasted. Now they decided, it would be a great move to make most models chargeable, [user, 2025-11-26](https://nl-be.trustpilot.com/review/highlightai.com)

    > the way they cap the usage into sessions and the weekly limit feels like a massive scam to farm money. [user, 2026-10-20](https://uk.trustpilot.com/review/claude.ai?page=4)

    > I paid for a pro version, and then they updated their app to a super complicated new version. [user, 2026-10-20](https://nl-be.trustpilot.com/review/highlightai.com)

12. **AI subscription apps as a class keep subscribers worse than other apps.** Side: against. Strength: medium (the researcher said strong; lowered in review). The data is App Store and Google Play apps, not Mac desktop tools, and the same sources carry good news that was left out.
    > Annual retention ... was 21.1% for AI apps, compared with a higher 30.7% for non-AI apps. [summary, 2026-03-10](https://techcrunch.com/2026/03/10/ai-powered-apps-struggle-with-long-term-retention-new-report-shows)

    > AI apps often have a one-and-done problem. [summary, 2026-08-18](https://www.revenuecat.com/blog/growth/ai-app-retention-study.md)

    > The novelty that converts so well wears off just as fast. [summary, 2026-08-18](https://www.revenuecat.com/blog/growth/ai-app-retention-study.md)

    > Utilities and Education lean toward high retention; Photo & Video and Media & Entertainment lean toward low. [summary, 2026-08-18, added in review](https://www.revenuecat.com/blog/growth/ai-app-retention-study.md)

    > AI apps convert users from trials to paid customers 52% better than non-AI apps (8.5% vs. 5.6% at the median). [summary, 2026-03-10, added in review](https://techcrunch.com/2026/03/10/ai-powered-apps-struggle-with-long-term-retention-new-report-shows)

13. **No evidence that a tool first used to learn software keeps being used for collaboration.** Side: against. Strength: weak, because it is an absence. The only material on churn after learning is a vendor blog. Context only.
    > The user achieved the goal that motivated them to sign up. Having achieved it, they have no reason to return. [vendor, 2026-04-26](https://dev.to/alichherawalla/what-to-build-in-your-edtech-app-when-better-test-scores-are-not-enough-to-retain-learners-1k78)

    > Learners who achieved their initial goal leave because the product gave them no reason to stay. [vendor, 2026-04-26](https://dev.to/alichherawalla/what-to-build-in-your-edtech-app-when-better-test-scores-are-not-enough-to-retain-learners-1k78)

14. **People default to the general assistant they already pay for.** Side: against. Strength: medium in direction, weaker in proof. The 80.4% figure is ChatGPT only, from a US e-receipt panel that may overstate retention.
    > those also paying for Claude had 72.5% six-month retention versus 80.4% for others. [summary, 2026-08-19](https://ask.yipitdata.com/insights/chatgpt-claude-dual-subscriber-retention)

    > Wenn ich KI brauche dann nehme ich Claude oder rChatGPT aber doch nicht einen MacLauncher [user, 2026-09-15](https://www.ifun.de/raycast-veraergert-nutzer-mit-neuem-ki-preismodell-288857/)

    In English, roughly: "If I need AI I use Claude or ChatGPT, not a Mac launcher".

    > I doubt anyone is paying $8/month for that alone. [user, 2023-05-11](https://talk.macpowerusers.com/t/ray-cast-introduce-subscription-based-raycast-pro/33583)

15. **Chat assistants that explain software in text often invent menus and commands.** Side: mixed. Strength: medium. It is a pain that pointing on the real screen could solve, and a warning: a guide that points wrong will be judged the same way.
    > The AI produced absolute nonsense, telling him to use non-existing commands in non-existing features. [vendor (the software's own developer), 2025-06-30](https://www.photools.com/community/index.php?msg=107216)

    > it'll just confidently make up some new menus. [user, 2025-07-02](https://www.photools.com/community/index.php?msg=107216)

    > It makes things up, tells me extremely detailed instructions that looks like they are real [user, 2025-11-05](https://feedback.clickup.com/feature-requests/p/please-remove-the-ai-that-is-giving-false-instructions)

16. **Trust in small screen-access apps is fragile.** Side: mixed. Strength: weak. One screen-aware assistant scores 2.7 out of 5 on 12 reviews, with repeated complaints that it stays on the machine after uninstall.
    > Keeping it short, same case as the other 2. Uninstalled but the app still on my device. [user, 2025-02-26](https://nl-be.trustpilot.com/review/highlightai.com)

    > Beware about downloading this on your PC/Mac... I uninstalled the program yet it is still on my screen. [user, 2025-01-07](https://nl-be.trustpilot.com/review/highlightai.com)

    > I found the app really useful and it helped speed up my manuscript writing [user, 2025-07-31](https://nl-be.trustpilot.com/review/highlightai.com)

### Counts

Researcher: 5 for, 5 against. The review says the counts look balanced by design and should not be read as weight. The real first-hand base is about 35 comments, and several findings rest on one to three people.

### Prices seen

- Raycast: Pro $10 a month with 500 AI credits; Pro+ $20 with 3,000; Max $50 with 7,500 (ifun.de, 14 September 2026). Raycast Pro was $8 a month at its 2023 launch.
- SuperCmd launcher: $19 one-time (reader comment).
- Clicky for Windows (third-party build): free, can run offline with local models.
- From search snippets only: Eney (MacPaw) $14.99 a month with a 14-day trial; Claude Pro with Cowork $20 a month; Gemini Mac app free.
- Littlebird: free Basic tier; see 12.5 for the checked prices.
- Highlight AI: was free with many models, later made most models paid. No figure seen.
- Copilot Vision with Highlights: no price on the opened pages.

### What the reviewer refuted

- **"Project memory is strongly wanted", rated strong.** Refuted in review. It rests on two people. Users who turn memory off and users whose trust was broken by faulty memory were missed. Memory is not proven as a reason to pay or stay. Visible, editable, user-controlled memory answers both camps, so the design choice holds.
- **"61% mainly ask for direct answers, so the teaching audience is a minority."** Refuted as a claim about audience size. The study is maths tasks in an experiment.
- **"AI apps retain worse", rated strong.** Lowered to medium. Mobile data, and utility and education apps sit in the better-retaining group.
- **"General assistants hold paying users at about 80% over six months."** One product, one US e-receipt panel (not a card panel), and the page itself warns retention may be overstated.
- **The Mindstudio comparison labelled "summary".** It is a vendor blog. Relabelled here; context only.
- **The first photools quote labelled "user".** It is the software's own developer. Relabelled here.
- **The guided study labelled as an independent summary.** It is the paper author's own blog.
- **Highlight review dated 2025-12-01.** The page shows 26 November 2025. Corrected here.
- **"Guided pointing is liked by early users."** The one enthusiastic user is also asking for "do it for me". A larger thread leans dismissive.

Added in review, a new trust risk: an overlay that points at the real interface is seen by some as a tool for scams or deception.

### What was not searched

- Reddit (r/macapps, r/ChatGPT, r/ClaudeAI): not reached. Mac App Store and Microsoft Store reviews: not reachable. G2 and Capterra: not opened.
- First-hand user feedback on Copilot Vision Highlights, the Gemini Mac app, Siri AI, Meta AI for Mac, Perplexity for Mac, Eney, Sky: only launch coverage and press found.
- Several forum threads and articles returned 403 (Windows Central, TechSpot, Windows Forum, AppleInsider, Lifehacker).
- The Product Hunt page for the 2.0 release of the pointing companion (agent mode): 404. Its move to background agents is known only from a search snippet.
- The full RevenueCat 2026 report: only the blog summary and press coverage were opened.
- X, YouTube comments, Discord: not searched.
- Agent adoption figures from a survey commissioned by an investor: seen in search snippets only, not opened, not counted.
- Any retention data for a learn-then-collaborate product: none found anywhere.

## 12.5 Q4. Privacy, always-watching tools and AI memory

Question: what do users say about tools that watch the screen all the time, about screen permissions, about AI memory of their work, and about workplace use? Does "looks only when called, memory encrypted on the device" matter to buyers? Would a tool that sends screenshots of internal systems to a cloud model be allowed at work at all?

### Findings

1. **Always-on screen recording draws flat rejection from many commenters.** Side: for. Strength: strong, for what it shows: dislike of always-on capture. It does not show that buyers value on-call capture.
   > I dont want any agent or any llm to know all the time what i have been doing on my system, it would be privacy nightmare [user, about July 2026](https://news.ycombinator.com/item?id=49024620)

   > This sounds so ripe for abuse and so terrifying if it were that I don't even want to experiment with it. Sorry. [user, about July 2026](https://news.ycombinator.com/item?id=49024620)

   > I don't want to be spied on at work or at home. [user, 2024-06-15](https://news.ycombinator.com/item?id=40677424)

   Note: the exact July dates in the first thread could not be confirmed in review.

2. **Many objectors want the function itself. Their conditions: local, encrypted, no telemetry, and a tool they chose to install.** Side: for. Strength: strong, with the same limit as finding 1. Source is from 2024.
   > I actually want this feature. My memory is awful and I am constantly going to Chrome's History function. This feature isn't bad, I just want it encrypted locally with no telemetry [user, 2024-06-19](https://news.ycombinator.com/item?id=40677424)

   > I'd love a tool like this. Except it's so thoroughly invasive and ripe for abuse that I can't imagine ever using something like this that isn't open source and thoroughly vetted. [user, 2024-06-14](https://news.ycombinator.com/item?id=40677424)

   > Having a tool like this planted in your device without your consent is pushing your userbase over the edge. [user, 2024-06-14](https://news.ycombinator.com/item?id=40677424)

3. **Always-on capture has a second cost: heat, CPU and battery. Users quit over it.** Side: for. Strength: medium, resting on one first-hand quote.
   > While I found it useful, I also found on my MacBook M1, the fact it was recording all the time, made my CPU melt at high temps all the time. I eventually had to shut it off and stop using because of that. [user, about July 2026](https://news.ycombinator.com/item?id=49024620)

   > The value that Rewind created was not quite enough to compensate. [summary, 2024-04-15](https://andrewschreiber.substack.com/p/an-early-adopters-thoughts-on-rewindais)

   Note: the second quote was labelled "user" by the researcher. The author is describing why other users left, so it is a summary.

4. **Employees read employer-imposed screen capture as surveillance.** Side: for (against forced always-on capture). Strength: medium. The conclusion "a tool must be visibly on-call and employee-controlled" is the researcher's inference, not what users said.
   > This makes me super uncomfortable. How do we opt out? [summary (an employee's comment as reported), 2026-04-22](https://www.entrepreneur.com/business-news/meta-will-track-every-click-and-keystroke-employees-make-backlash)

   > I do not think it is cynical to assume that Microsoft would sell this to companies as a way to do constant surveillance of their employees [user, 2024-06-14](https://news.ycombinator.com/item?id=40677424)

5. **In companies, screen capture hits a compliance wall, and local-only storage does not remove it.** Side: against. Strength: strong.
   > The 'record everything on your screen' pitch keeps hitting a privacy wall for teams — even local-only storage triggers a brutal compliance conversation. What's the story for an engineer whose company blocks unaudited desktop recorders by policy? [user, about July 2026](https://news.ycombinator.com/item?id=49024620)

   > zero chance im trusting any cloud or third party SaaS if this doesn't run fully local its a no go for enterprise let alone ordinary users [user, about July 2026](https://news.ycombinator.com/item?id=49024620)

   > way too much of a security concern, especially on a work laptop. [summary (an academic quoted in a trade article), no date given, added in review](https://www.hrreporter.com/focus-areas/automation-ai/a-hard-no-next-wave-of-agentic-ai-upping-the-ante/394221)

6. **In the EU, two commenters say employer-side tools that track what staff do on screen are unlawful or stopped by a works council.** Side: against. Strength: weak, an unverified legal claim (the researcher said medium; lowered in review). The comments are about an always-on recorder. A tool the worker calls himself, with no employer view, may fall outside it.
   > european employers would break laws by allowing your software to be used, long even before AI became a thing and especially after the EU AI Act has passed. [user, about July 2026](https://news.ycombinator.com/item?id=49024620)

   > Anything that tracks employees actions beyond high-level "are they doing their job according to the job descriptions" is forbidden by privacy laws and otherwise will be striken down by a workers council. [user, about July 2026](https://news.ycombinator.com/item?id=49024620)

7. **IT's default answer to unapproved AI tools: prohibit by default, allow by exception.** Side: against. Strength: medium. "Block everything" is one top reply in a forum thread, not a consensus; the most repeated point there is that blocking fails.
   > argues for blocking everything, then granting approved access to chosen services. [summary, 2026-08-06](https://comparethecloud.net/articles/shadow-ai-uk-it-managers/)

   > Establish a company policy and inform employees that the use of system-level visual AI assistants is prohibited. [vendor, 2024-07-23](https://www.kaspersky.com/blog/it-compliance-of-microsoft-copilot-recall-apple-intelligence-google-astra/51769)

   Note: the second quote is cut. The page continues: "Grant exceptions on a case-by-case basis for specific uses."

8. **Companies already allow screen sharing to a cloud assistant, when it comes from the incumbent.** Side: against for the B2B niche. Added in review. The dominant office suite ships user-started screen sharing with its assistant, on by default for licensed business users, with an admin off-switch and 48-hour deletion.
   > Every sharing session is entirely user-initiated [summary, 2026-06](https://blog.topedia.com/2026/06/vision-in-microsoft-365-copilot-screen-and-camera-sharing-on-desktop-and-mobile/)

   > will be available by default for users with a Microsoft 365 Copilot license. [summary, 2026-06](https://blog.topedia.com/2026/06/vision-in-microsoft-365-copilot-screen-and-camera-sharing-on-desktop-and-mobile/)

9. **In practice many people trade privacy for convenience.** Side: against. Strength: medium (the researcher said strong; lowered in review). The evidence is about chatbots and meeting notetakers, not screen capture, and about a quarter of people refuse outright.
   > a full block does not remove the behaviour, it removes your visibility of it. [summary, 2026-08-06](https://comparethecloud.net/articles/shadow-ai-uk-it-managers/)

   > 25.1% were never asked and simply saw the bot appear in the meeting. [summary commissioned by a law firm, 2026-07-16](https://stacker.com/stories/business-economy/ai-notetakers-have-sat-1-3-us-workers-meetings-only-third-say-they-were)

   > One Nudge Security customer saw 800 new accounts created in just 90 days. [vendor, 2026-01-19](https://nudgesecurity.com/post/shadow-ai-is-taking-notes-the-growing-risk-of-ai-meeting-assistants)

   Note: the notetaker figure comes from a subsample of 167 people.

10. **Surveys show high stated discomfort and a reluctant yes.** Side: mixed. Strength: medium. The study was commissioned by a consent-management vendor (11,000 consumers, 7 markets). The same study reports 23% who refuse outright and 24% who would abandon a product over financial access.
    > just 7% of consumers are fully comfortable granting an AI assistant access to their data with no conditions attached. [summary commissioned by a vendor, 2026-09-29](https://agilebrandguide.com/resigned-consent-new-global-study-finds-consumers-grant-ai-access-reluctantly-more-than-twice-as-often-as-willingly/)

    > More than twice as many, 17%, grant that access despite feeling uncomfortable about it [summary commissioned by a vendor, 2026-09-29](https://agilebrandguide.com/resigned-consent-new-global-study-finds-consumers-grant-ai-access-reluctantly-more-than-twice-as-often-as-willingly/)

    > We admit, our sample is probably skewed towards the privacy conscious. [vendor, 2026-03-17](https://www.malwarebytes.com/blog/privacy/2026/03/90-of-people-dont-trust-ai-with-their-data)

11. **Stated willingness to pay for privacy exists in surveys.** Side: for. Strength: weak. Added in review. Both surveys are by privacy vendors and measure what people say, not what they do.
    > Half (50%) of US consumers will pay more for a brand that is transparent about how it uses AI with their data. [vendor, July 2026](https://usercentrics.com/press/usercentrics-state-of-digital-trust-2026-report-us-findings/)

    > nearly all of those same people continue using those platforms anyway. [vendor, survey of April 2026](https://ppc.land/only-18-of-americans-trust-ai-with-their-data-meta-ai-leads/)

    Added in review: in the second survey (1,009 US adults), 44% say they would pay more for a guarantee of no AI processing, and only 18% trust AI with their data.

12. **On-device encryption raised trust in the best-known Mac screen recorder, but did not offset its performance cost.** Side: mixed. Strength: weak to medium (the researcher said strong, and concluded "privacy does not retain"; refuted in review). The lesson is about performance and accuracy.
    > You could trust it more, because the raw data was (mostly) kept on-device in an encrypted database. [user, 2024-04-15](https://andrewschreiber.substack.com/p/an-early-adopters-thoughts-on-rewindais)

    > The cloud-based storage model merited an application rewrite. [user, 2024-04-15](https://andrewschreiber.substack.com/p/an-early-adopters-thoughts-on-rewindais)

13. **The closest competitor gets privacy doubt from its own launch audience.** Side: mixed. Strength: medium at most: about six user comments visible, about half raise privacy or unease. Even an on-call tool has to prove itself.
    > The constant visibility is the double-edged sword here. I'd want a timed context window, not always-on capture. [user, 2026](https://www.producthunt.com/posts/clicky-2)

    > Might be more difficult to convince people that it won't do something weird than to actually achieve it [user, 2026](https://www.producthunt.com/posts/clicky-2)

    > I think there must be a great security concern and privacy policy [user, 2026](https://www.producthunt.com/posts/clicky-2)

14. **"Stored locally" is not believed on a vendor's word. Users ask for proof.** Side: mixed. Strength: medium. An encrypted Map helps only if it can be shown.
    > Can we trust Microsoft that data will solely be stored locally? [user, 2024-05-23](https://www.schneier.com/?p=68947)

    > People will tolerate a lot of passive collection if they can see the receipts on what it's doing with it and where an answer traces back to. [user, about July 2026](https://news.ycombinator.com/item?id=49024620)

    > "opt-in" isn't good enough. [user, 2024-06-08](https://forums.tomshardware.com/threads/microsoft-backtracks-on-new-recall-feature-%E2%80%94-enhancing-recalls-security-and-making-it-an-opt-in-decision.3846565/page-2)

15. **AI memory of personal and work data: useful, and uneasy about one store holding everything. Others shrug.** Side: mixed. Strength: weak, and old (2024).
    > Storing so much personal information **in one place** feels risky. [user, 2024-10-17](https://community.openai.com/t/privacy-concerns-in-chatgpts-memory-system/982636)

    > it's highly unlikely that anyone would be scrutinising it individually. [user, 2024-10-27](https://community.openai.com/t/privacy-concerns-in-chatgpts-memory-system/982636)

    > It can't be trusted to maintain anything secret. [user, 2024-10-28](https://community.openai.com/t/privacy-concerns-in-chatgpts-memory-system/982636)

16. **The largest assistant vendor now ships opt-in Mac activity memory, off by default and admin-gated for business seats, with memory files stored unencrypted.** Side: mixed. Strength: weak, from a competitor's blog. Encrypted on-device memory is a real difference, but a big vendor with admin controls is what IT will approve first. The page also says the feature takes no screenshots.
    > Computer History is a distinct setting inside the ChatGPT Mac app, off by default, tucked under Settings → Integrations. [vendor, 2026-08-14](https://elephas.app/resources/chatgpt-desktop-computer-history-privacy)

    > Business and Enterprise seats need an admin to turn it on first through Workspace Settings. [vendor, 2026-08-14](https://elephas.app/resources/chatgpt-desktop-computer-history-privacy)

17. **macOS asks the user to re-approve screen recording every month, and the app cannot switch that off.** Side: against. Added in review. Any screen-reading Mac app inherits this. The source is from 2024; nothing was found on whether the newest macOS changed it.
    > still interrupt the user’s work too frequently. [summary, 2024-09-23](https://tidbits.com/2024/09/23/how-to-avoid-sequoias-repetitive-screen-recording-permissions-prompts/)

    > This is really going to drive people crazy with Zoom / Teams / WebEx / Google Meet, etc., etc., etc. [user, 2024-09-23](https://tidbits.com/2024/09/23/how-to-avoid-sequoias-repetitive-screen-recording-permissions-prompts/)

### Counts

Researcher: 4 for, 4 against, 6 mixed. The review says these count claims, not independent sources: three "for" findings and two "against" findings draw on the same two forum threads, and both threads are about always-on recorders. About half the evidence is from 2024.

### Prices seen

- Littlebird: Basic $0; Plus $17 a month billed yearly or $20 monthly; Power $42 a month yearly or $510 upfront (a reviewer, 26 September 2026).
- Cluely: free tier; Pro $19.99 a month; Pro + Undetectability $149.99 a month; Enterprise about $200 a month (a competitor's blog, July 2026).
- Clicky: listed Free on Product Hunt; a competitor's blog reports Pro at $20 a month for 150 agent messages.
- Elephas: from $19 a month.
- ChatGPT Computer History: only on Pro, Business and Enterprise plans; not in the EEA, UK or Switzerland; no price on the page.
- Screenpipe: free tier plus paid and Enterprise plans; no figures on the page.
- Rewind / Limitless: Mac capture disabled 19 December 2025; pendant sales ended 5 December 2025.
- Microsoft Recall: no separate price, bundled with Copilot+ PCs, opt-in.

### What the reviewer refuted

- **The "necessary evil" quote used as proof that IT blocks first.** Removed from finding 7. The quote is real but "they" are data-loss-prevention tools that a regulated health company ran on staff machines. If anything it shows regulated firms accept invasive tooling when compliance needs it.
- **"On-device encryption did not keep users. Privacy alone does not retain."** Refuted in review as an overreach from one April 2024 post. The author never says he quit. The product ended by acquisition, not by measured churn.
- **The EU works-council finding, rated medium.** Lowered to weak. Law-firm summaries seen in search results say the trigger is whether a tool can monitor behaviour or performance, and that not every AI tool triggers co-determination. Those pages could not be opened, so this counter-point is unverified too. It needs a lawyer, not more forum reading.
- **"No data found on willingness to pay extra for privacy."** A search gap. Survey data exists (finding 11). Still no evidence of actual purchase behaviour.
- **"People trade privacy for convenience", rated strong.** Lowered to medium.
- **"Security advice names screen-reading assistants as something to prohibit."** The quote was cut. The same item allows case-by-case exceptions and a pilot path.
- **The Meta employee quote.** It is about forced tracking with no opt-out, not about a tool the worker calls himself.
- **"Looks only when called" as a difference.** Corrected. It is the normal shape now (finding 8). The encrypted on-device memory is the only part still distinct, and no user evidence was found that it wins a sale.
- **"Would screenshots of internal systems to a cloud model be allowed at all?"** The researcher's answer was "blocked by default". The review's answer is: yes in principle, from an incumbent with an admin switch, short retention and a contract. The real barrier is that a small unknown vendor must pass the same security review. That is a competition problem as much as a privacy one.

### What was not searched

- Reddit (r/sysadmin, r/technology): 403. G2, Capterra and app-store reviews of screen-aware assistants and screenshot-based training tools: none reached.
- Several articles returned 403 or loaded only a headline (GeekWire, TechSpot, Windows Central, MarketingProfs, WebProNews). No pro-Recall quote could be taken.
- The two law-firm pages on works councils: not opened.
- No first-hand account of a company approving or refusing a tool that sends screenshots of internal systems to a cloud model. Every B2B conclusion here is by analogy.
- No user reviews of Littlebird or Highlight on this question.
- Italian and other non-English sources.
- The part of the question on screen-recording permissions was not covered by the researcher; the review added finding 17 only.

## 12.6 What must be true for the direction to work, and the cheapest test for each

Each line is a condition. If it turns out false, the part of the direction named in brackets does not hold.

1. **Pointing is right, reliably, on the current version of each chosen app.** [a] This is the edge that is left. Seeing the screen does not fix accuracy by itself: two independent sources show screen-seeing guides giving wrong steps.
   Cheapest test: write 20 real tasks per app. Run Phew on each. Count how many it gets right the first time. Ask a general chat assistant the same 20 and compare. No users needed.

2. **Some people will pay about $20 a month for it.** [a] Nobody was found who pays or says they would.
   Cheapest test: first, read by hand what both passes could not open: Reddit, the Autodesk forum, software-directory and App Store reviews of the closest competitors. Then a paying test with real users: a small paid pilot or a real price asked of 10 to 20 learners. A promise to pay does not count.

3. **People who have learned keep using it for collaboration.** [b] No evidence either way.
   Cheapest test: interviews with 10 people who learned a hard app in the last two years. Ask what they use now, and when they last needed help. Later, with real users: count calls per person per week over 8 to 12 weeks and see whether they continue after the first weeks. Only the count is needed, never the words.

4. **It gives something the general assistant people already pay for does not.** [a, b] Those assistants are adding screen view, memory and projects. They talk and do not point.
   Cheapest test: the same 10 tasks, side by side, with Phew and with a general assistant that can see the screen. Five users choose which they would keep, and say why.

5. **New users know what to ask.** [a, c] Call-only assumes the user can form a question. A brand-new worker often cannot, which is why incumbents sell proactive guidance.
   Cheapest test: watch 5 people on software they have never used. Note each time they are stuck and do not call.

6. **Users accept that the screen is sent to a cloud model by a small company.** [a] "Sending many whole screenshots to an indie mystery box" is the objection on record.
   Cheapest test: show the consent screen wording to 10 people before they try the app. Ask what would stop them.

7. **The legacy software in the target firms runs on Macs.** [c] Macs are about 11% of US enterprise PCs; much legacy software arrives through Citrix.
   Cheapest test: list 10 kinds of firm from `docs/08-b2b-targets.md`. For each, find out what the workers' machines are and how the software is delivered. Five phone calls answer most of it.

8. **IT will allow a screen-reading assistant from a small vendor.** [c]
   Cheapest test: ask 3 people who run IT or security what they would require before approving it. Bring a one-page drawing of where the data goes.

9. **EU monitoring rules do not block a tool the worker calls himself, with no employer view.** [c]
   Cheapest test: one hour with a lawyer who knows employment and privacy law.

10. **There is a reason for a firm to pick this over the screen-sharing assistant it already pays for.** [c]
    Cheapest test: put the question plainly to the same 3 IT people from test 8.

11. **The macOS screen-recording re-approval is tolerable.** [a]
    Cheapest test: check how the current macOS behaves on the test Mac. The source found is from 2024.

## 12.7 What this changes

These are suggestions for the owner. None is a decision. This report edits no other file; the open decisions below still need to be listed under Open in `docs/07-decisions.md`.

### The direction

- **Keep "teach the software you work in" as the way in.** Present it as a wedge for people learning hard tools, where the praise actually sits (3D, CAD, design). Do not present it as proven to pay.
- **Treat "collaboration stops cancelling" as a hypothesis.** Write it as something to test, with tests 3 and 4 above, not as a reason the business works.
- **Move B2B legacy training out of "first paid niche".** Keep it as a later option with its own research, as already planned for after the MVP. Do not use the $30,000 to $40,000 contract figures as its market size. Before naming it again, answer tests 7 to 10.
- **Make accuracy on the current version the product.** The evidence that helps most is "the chat assistant does not know the current version" and "tutorials are outdated". This supports the plan to research each app before use, so that Phew starts with knowledge. It also carries a warning: the same complaint will hit Phew once that research ages. One-time research is fine for now; the report only notes that the staleness problem is the very pain being sold against.
- **Decide what "collaborate" means when users ask him to act.** The pressure from "do it for me" is real. Today's rule is that an agent changes nothing except new files. That may be the right line; consumers are risk-averse about autonomous actions. It is an open decision, not a settled one.
- **Never guide unasked.** The existing rule matches the strongest end-user finding (pop-ups are hated). Keep it.
- **Expect the "first payment easy, staying hard" pattern.** AI apps convert trials well and lose subscribers sooner. Plan the early test around whether people stay, not whether they try.

### The MVP app list

The list is Figma, Excel, Autodesk Fusion, a browser, Notes, Reminders, Calendar. What the evidence says about each:

- **Autodesk Fusion.** The most learner pain found: outdated tutorials, unexplained icons, struggling alone. But the voices are hobby machinists, mostly from 2019 to 2020. Autodesk's own assistant is in technical preview; no user feedback on it was found. Best candidate for the accuracy test.
- **Figma.** One first-hand post about not finding a control after the interface redesign. No learner was found asking for in-app help. Figma has its own in-app agent that answers how-to questions; nothing was found on how good it is.
- **Excel.** One course review about outdated commands. This is also where free substitutes are strongest: a built-in assistant, and a free screen-sharing assistant already tested first-hand on a pivot table. Paying Excel users here mostly want the task done. The hardest place to stand out.
- **A browser.** No evidence either way. Nothing was found on Dia.
- **Notes, Reminders, Calendar.** No ordinary user was found asking for a tutor for these. The only demand found is for older or less technical people, raised by their relatives. These apps may still matter for the collaboration side and for the Map. They are weak proof of the teaching side.

Suggested order of research effort, if the per-app knowledge research is done one app at a time: Fusion, then Figma, then Excel, then the simple apps. This order is an inference from thin evidence, not a finding.

### The privacy stance

- **Keep it as it is. Do not sell on it.** "Looks only when called, memory encrypted on the Mac" is the price of entry. It is what objectors ask for, and it avoids the heat and battery cost of always-on tools. No evidence shows that anyone buys or stays because of it, and user-started screen sharing is now normal.
- **Say plainly where the screenshot goes.** The question users actually ask is "is my screen sent to a server?". The honest answer is yes, to the model, when called. "Encrypted on the device" says nothing about that send. The consent screen should answer it in one sentence.
- **Show, do not promise.** "Stored locally" is not believed on a vendor's word. Let the user see what the Map holds, where an answer came from, and edit or delete it. This also answers the people who switch memory off to keep control.
- **Memory must be right or say it is unsure.** Memory that invents context makes users stop trusting the whole project.
- **Quit and uninstall cleanly.** A screen-aware competitor is rated 2.7 out of 5 largely because it stays on the machine after uninstall.
- **Know the overlay risk.** Some people see an overlay that draws on the real interface as a scam tool. Worth one line in how Phew introduces himself.
- **Check the monthly screen-recording prompt** on the current macOS (test 11).
- **For B2B later, the list is longer:** a security review pack, a data-processing agreement, a no-retention guarantee from the model provider, redaction, and proof that the employer cannot use it to watch staff.

No rule in `CLAUDE.md` needs to change because of this report.

## 12.8 Products met

Input for the competitor map. Prices are as seen in the sources; "search result" means the page was not opened.

### Tools that see the screen and point or guide

| Name | What it does | Price | Link |
|---|---|---|---|
| Clicky (macOS) | Open-source menu-bar companion. A pointer beside the cursor sees the screen, talks and points at interface elements. Sends screenshots to a cloud model. A 2.0 release reportedly added background agents (not verified). Closest product to the direction. | Free tier (25 talk messages a month); Pro $20 a month; Max $100 a month. Open-source version free with your own API keys. | https://heyclicky.com and https://github.com/farzaa/clicky |
| Clicky for Windows (third-party) | Free "AI tutor" beside the cursor: points, explains, quizzes; offline mode with local models. | Free | https://www.producthunt.com/p/clicky-3/clicky-4 |
| Ourguide | macOS step-by-step guidance on request that shows where to click in any app. | Free to use | https://hn.algolia.com/api/v1/items/46769422 |
| Spotit | Mac app: ask a how-to question by shortcut and it highlights the next thing to click. | Free to try; no paid tier shown | https://hunted.space/product/spotit-3 |
| Guidy | Windows desktop assistant that sees the screen and guides in any software. | Not seen | https://betalist.com/startups/guidy |
| Microsoft Copilot Vision with Highlights | Built into the Windows Copilot app. Share a window, say "show me how", and it highlights where to click. Tests report both accurate and wrong guidance. | Free | https://www.windowslatest.com/2025/08/07/windows-11s-built-in-copilot-vision-that-can-see-your-screen-now-works-for-free-everywhere-hands-on |
| Vision in Microsoft 365 Copilot | User-started screen and camera sharing with the office assistant, on by default for licensed business users, with admin controls and 48-hour deletion. | Included with a Microsoft 365 Copilot licence | https://blog.topedia.com/2026/06/vision-in-microsoft-365-copilot-screen-and-camera-sharing-on-desktop-and-mobile/ |
| Google AI Studio screen share | Free screen-sharing chat assistant that talks users through tasks by voice. Tested first-hand on a spreadsheet. Does not point. | Free | https://www.benlcollins.com/?p=21298 |
| Helpmee AI | Voice and screen-sharing assistant that guides seniors through computer problems. | Free 30 minutes a month; paid tiers not priced on page | https://www.producthunt.com/posts/helpmee-ai |
| pointer.so | B2B "second cursor" embedded in a company's own product to guide its users. | Not seen | https://news.ycombinator.com/item?id=43201878 |
| Knowable | Camera-based AI tutor on the Mac App Store. Too few ratings to show a score. | $24.99 a month | https://apps.apple.com/app/knowable/id6763789090 |
| Skilly, Luma, LearnByDoing, Pointer, bigarrow | Other pointing or screen-guide tools. Search results only. | Not seen | none opened |
| Hover, Vida, Attyn | Other Mac screen assistants. Search results only. | About $8, $9.90 and $15 a month | none opened |

### General assistants and screen-aware companions

| Name | What it does | Price | Link |
|---|---|---|---|
| ChatGPT (desktop, Projects, memory, agent) | General assistant. Users ask for visible, editable project memory and exact retrieval. Agent mode reviewed as slow. Screen context in voice mode for paid plans (search result). | Not seen in opened pages | https://community.openai.com/t/projects-are-containers-not-archives-large-projects-need-retrieval-not-just-memory/1383739 |
| ChatGPT Computer History (Mac) | Opt-in log of clicks, typing and app switches turned into memory. Off by default, admin-gated on business plans. Takes no screenshots. Memory files unencrypted on the Mac. | Pro, Business and Enterprise plans only | https://elephas.app/resources/chatgpt-desktop-computer-history-privacy |
| Claude (desktop, Cowork) | General assistant with a desktop agent. Trustpilot reviews 81% one-star, mostly usage limits, reliability, support and memory. | $20 a month Pro (search result) | https://uk.trustpilot.com/review/claude.ai?page=4 |
| Gemini for Mac, Meta AI for Mac, Perplexity for Mac, Sky | Screen-aware Mac assistants. Launch coverage only; no user feedback reached. | Gemini free (search result) | none opened |
| Eney (MacPaw) | Mac assistant. Launch coverage only. | $14.99 a month, 14-day trial (search result) | none opened |
| Highlight AI | Screen-aware desktop assistant. Trustpilot 2.7 out of 5 on 12 reviews: uninstall problems, pricing change, redesign. | Was free; later most models paid. No figure seen | https://nl-be.trustpilot.com/review/highlightai.com |
| Littlebird | Mac assistant that builds a running memory from screen text, meetings and connected tools. Memory encrypted in the cloud, not local-only. | $0; $17 to $20; $42 a month | https://www.producthunt.com/products/littlebird/reviews |
| Raycast AI | Mac launcher with AI. Moved to usage-based AI credits in September 2026 and angered users. | $10, $20, $50 a month | https://www.ifun.de/raycast-veraergert-nutzer-mit-neuem-ki-preismodell-288857/ |
| Cluely | Overlay that listens to calls and reads the screen to show answers live. | Free; $19.99; $149.99; about $200 enterprise a month | https://www.usecarly.com/blog/cluely-vs-clicky/ |
| Elephas | Mac AI assistant sold on privacy. | From $19 a month | https://elephas.app/resources/chatgpt-desktop-computer-history-privacy |
| Cowork with Chronicle, Poke, Cluey | Consumer agents compared in a vendor blog. | Not seen | https://www.mindstudio.ai/blog/poke-vs-clicky-vs-cluey-vs-co-work-consumer-agent-comparison |
| SuperCmd | Mac launcher named by a reader as a one-time-price alternative. | $19 one-time | none opened |

### Always-on recorders

| Name | What it does | Price | Link |
|---|---|---|---|
| Microsoft Recall | Windows feature that snapshots the screen every few seconds for search. Backlash forced opt-in, encryption and sign-in. Blocked by default by Signal, Brave and AdGuard. | Bundled with Copilot+ PCs | none opened |
| Rewind / Limitless | Mac always-on screen and audio recorder with an on-device encrypted store. Moved to the cloud and a pendant, bought by Meta, capture disabled December 2025. | Discontinued | https://9to5mac.com/2025/12/05/rewind-limitless-meta-acquisition/ |
| Screenpipe | Open-source 24/7 local screen and audio recorder that feeds AI agents. App filters, schedules, on-premise for enterprise. | Free tier, paid and Enterprise plans | https://news.ycombinator.com/item?id=49024620 |
| Meta internal tracking tool | Employer tool logging clicks, keystrokes and periodic screenshots on work laptops to train agents. No opt-out. Employee backlash. | Internal | https://www.entrepreneur.com/business-news/meta-will-track-every-click-and-keystroke-employees-make-backlash |

### Built-in AI inside the MVP apps

| Name | What it does | Price | Link |
|---|---|---|---|
| Copilot in Excel | Built-in assistant in Excel. Complaints: explains instead of acting, wrong results, poor value. | In Microsoft 365 Personal at $9.99 a month; business add-on $21 per user per month (search result) | https://techcommunity.microsoft.com/discussions/microsoft365copilot/microsofts-copilot-a-frustrating-flop-in-ai-powered-productivity/4221190 |
| Figma AI and Figma agent | Built-in generation plus an in-app agent that answers how-to questions from the Help Center. No user feedback found on the how-to answers. | Not seen | https://forum.figma.com/report-a-problem-6/ongoing-issues-with-figma-ai-incorrect-or-fake-ui-outputs-51430 |
| Autodesk Assistant (Fusion) | Built-in assistant in Fusion, in technical preview. No user feedback reached. | Not seen | https://help.autodesk.com/cloudhelp/2027/ENU/WSPro-Help/files/GUID-9017743B-6B2E-41D1-BF66-EF3FEFEFCAB2.htm |

### Workplace guidance and training tools

| Name | What it does | Price | Link |
|---|---|---|---|
| WalkMe (owned by SAP) | Digital adoption platform: authored on-screen walkthroughs and pop-ups over enterprise apps. Announcing proactive AI (Action Bar). | Median about $39,000 a year; range $14,400 to $197,118 | https://www.vendr.com/buyer-guides/walkme |
| Whatfix | Digital adoption platform for employee software training and in-app guidance. | Median $31,950 a year; custom quote only | https://vendr.com/marketplace/whatfix |
| Userlane | Digital adoption platform aimed at employee training. | About $18,000 a year on average (search result) | none opened |
| Pendo | Product analytics plus in-app guides, mainly for product teams. | Median about $48,500 a year (search result) | none opened |
| Tango | Captures a workflow as a step-by-step guide with screenshots; can highlight the next element live. Sells redaction of sensitive data. | Free; Pro $22 a month; Enterprise custom | https://toolradar.com/tools/tango/pricing |
| Scribe | Generates how-to guides with screenshots from a recorded workflow. Sells redaction of sensitive data. | About $23 per seat a month (search result) | https://www.producthunt.com/posts/cursive-2/reviews |
| UserGuiding | Lower-cost onboarding and walkthrough builder. | Not seen | https://userguiding.com/blog/walkme-reviews |
| Chameleon | Product tour builder; publishes tour completion figures. | Not seen | https://www.chameleon.io/blog/mastering-product-tours |
| CommandBar (Command AI) | User-assistance tool positioned against pop-up based adoption tools. | Not seen | https://userobsession.substack.com/p/are-we-crazy-from-digital-adoption |
| uPerform | Training content platform for hospital record systems and ERP. | Not seen | https://www.uperform.com/blog/epic-training-for-nurses/ |
| Citrix App Protection | Not a competitor. A control that blocks screen capture by AI tools in Citrix sessions, on Mac too. | Not seen | https://docs.citrix.com/en-us/citrix-workspace-app/app-protection/app-protection-blocking-unauthorized-ai.html |

### Learning by video and courses

| Name | What it does | Price | Link |
|---|---|---|---|
| Udemy | Course marketplace used for Fusion and Excel. Trustpilot 1.6 out of 5 from 1,987 reviews; complaints of outdated and basic content. | Under $20 per course (user report) | https://www.trustpilot.com/review/udemy.com?page=6 |
| Coursera (IBM Excel basics course) | Online course; one reviewer reports outdated commands. | Not seen | https://www.coursera.org/programs/learning-program-e9odo/learn/excel-basics-data-analysis-ibm/reviews?page=86 |
| YouTube tutorials | The default free way to learn Fusion and other pro apps. | Free | none opened |

## 12.9 Sources

Every URL used, grouped by question, with its label. Labels are as corrected by the review.

### Q1

- https://epiusers.help/t/new-user/74781 — user
- https://www.epiusers.help/t/switching-from-epicor-to-sap-any-advice/136702.md — user
- https://www.epiusers.help/t/what-is-this-personalize-homepage/122087 — user
- https://www.techtarget.com/searchhealthit/news/366628533/KLAS-Training-and-governance-needed-to-address-EHR-burnout — summary
- https://www.tradeandindustrydev.com/industry/technologyrd/worker-survey-finds-us-companies-falling-short-34849 — summary, from a consulting firm with an interest
- https://www.vendr.com/buyer-guides/walkme — summary
- https://vendr.com/marketplace/whatfix — summary
- https://userpilot.com/blog/whatfix-pricing/ — summary, a competitor repeating Vendr data
- https://www.costbench.com/software/digital-adoption-platform/walkme/hidden-costs/ — summary
- https://userguiding.com/blog/walkme-reviews — summary, a competitor's selection of reviews
- https://softwarefinder.com/lms/whatfix — user
- https://www.peerspot.com/products/walkme-reviews — user (added in review)
- https://hn.algolia.com/api/v1/search_by_date?query=%22product%20tours%22&tags=comment&hitsPerPage=30 — user
- https://hn.algolia.com/api/v1/search?query=%22green%20screen%22%20training%20employees&tags=comment&hitsPerPage=30 — user
- https://hn.nuxt.dev/item/48028546 — user
- https://hn.nuxt.dev/item/43348379 — user
- https://hn.algolia.com/api/v1/items/46769422 — user and vendor, same thread (added in review)
- https://www.walkme.com/blog/q1-26-release/ — vendor
- https://www.chameleon.io/blog/mastering-product-tours — vendor
- https://userobsession.substack.com/p/are-we-crazy-from-digital-adoption — vendor
- https://www.computerworld.com/article/4154950/apples-mac-grabs-11-of-us-enterprise-market-share.html — summary (added in review)
- https://docs.citrix.com/en-us/citrix-workspace-app/app-protection/app-protection-blocking-unauthorized-ai.html — vendor (added in review)
- https://www.hcinnovationgroup.com/clinical-it/electronic-health-record-electronic-medical-record-ehr-emr/news/53098701/emory-healthcare-first-to-use-epic-on-the-mac-at-scale — summary (added in review)
- https://betalist.com/startups/guidy — vendor (added in review)
- https://toolradar.com/tools/tango/pricing — summary (price only)
- https://www.producthunt.com/posts/cursive-2/reviews — product page (product list only)
- https://www.uperform.com/blog/epic-training-for-nurses/ — vendor (product list only)

### Q2

- https://homemodelenginemachinist.com/threads/fusion-360-for-a-beginner.31495/page-2 — user
- https://forum.onefinitycnc.com/t/how-did-you-learn-fusion/30471 — user
- https://forum.onefinitycnc.com/t/ai-to-help-with-fusion-360-commands/26392 — user
- https://www.coursera.org/programs/learning-program-e9odo/learn/excel-basics-data-analysis-ibm/reviews?page=86 — user
- https://forum.figma.com/share-your-feedback-26/ui3-feedback-3058/index39.html — user
- https://www.renderhub.com/blog/poll-which-learning-format-do-you-prefer — summary, with one user comment
- https://macmost.com/why-ai-cant-replace-tech-help-yet.html — summary
- https://hn.svelte.dev/item/46769422 — user and vendor, same thread
- https://techcommunity.microsoft.com/discussions/microsoft365copilot/microsofts-copilot-a-frustrating-flop-in-ai-powered-productivity/4221190 — user
- https://techcommunity.microsoft.com/discussions/microsoft365copilot/copilot-in-excel-performs-data-manipulation-once-and-then-refuses-all-subsequent/4444281 — user
- https://techcommunity.microsoft.com/discussions/microsoft365copilot/such-a-disappointment/4296967 — user
- https://office-watch.com/2026/copilot-function-excel-accuracy-errors/ — summary
- https://www.trustpilot.com/review/udemy.com?page=6 — user
- https://hunted.space/product/spotit-3 — vendor
- https://www.hunted.space/product/clicky-2 — user
- https://www.producthunt.com/products/spotit-3 — user
- https://www.producthunt.com/posts/helpmee-ai — user
- https://theoutpost.ai/news-story/microsoft-s-copilot-vision-falls-short-of-marketing-promises-in-real-world-testing-21776/ — summary, an AI-written aggregator, weak
- https://www.windowslatest.com/2025/08/07/windows-11s-built-in-copilot-vision-that-can-see-your-screen-now-works-for-free-everywhere-hands-on — summary
- https://www.windowslatest.com/2025/11/19/microsoft-yanks-copilot-ad-after-ai-fails-at-a-basic-windows-11-task-grandma-could-spot — summary (added in review)
- https://techcrunch.com/2026/03/10/ai-powered-apps-struggle-with-long-term-retention-new-report-shows — summary
- https://heyclicky.com — vendor (added in review)
- https://www.benlcollins.com/?p=21298 — user (added in review)
- https://fortune.com/2026/10/01/gen-z-ai-learning-struggle-to-apply-survey/ — summary of a tutoring company's survey (added in review)
- https://churnkey.co/use-case/edtech — vendor (added in review)
- https://apps.apple.com/app/knowable/id6763789090 — vendor (added in review)
- https://github.com/farzaa/clicky — product page (product list only)
- https://help.autodesk.com/cloudhelp/2027/ENU/WSPro-Help/files/GUID-9017743B-6B2E-41D1-BF66-EF3FEFEFCAB2.htm — vendor (product list only)

Opened, quote dropped after review:

- https://discussions.apple.com/thread/255827984 — user. The quote is real but answers a human's instructions, not an AI. Not used.
- https://forum.figma.com/report-a-problem-6/ongoing-issues-with-figma-ai-incorrect-or-fake-ui-outputs-51430 — user. The quote is real but about AI design generation, not learning help. Not used as evidence; kept only as the product link for Figma AI.

### Q3

- https://www.producthunt.com/posts/clicky-2 — user
- https://www.mindstudio.ai/blog/poke-vs-clicky-vs-cluey-vs-co-work-consumer-agent-comparison — vendor (relabelled in review)
- https://xiaotiansu.github.io/blog/2025/guided — the study author's own blog, with a participant quote
- https://artificialcorner.com/p/my-honest-review-of-chatgpt-agent — user
- https://macdailynews.com/2026/02/13/apple-studies-what-real-users-expect-from-ai-agents/?noamp=mobile — summary
- https://arxiv.org/abs/2509.14528 — summary
- https://arxiv.org/abs/2601.20245 — summary (added in review)
- https://the-decoder.com/just-ten-minutes-of-using-ai-as-an-answer-machine-can-measurably-erode-problem-solving-skills-new-study-finds/ — summary
- https://community.openai.com/t/give-chatgpt-a-user-controlled-persistent-project-memory-rules-structured-state-so-it-can-behave-like-a-consistent-long-term-collaborator-instead-of-a-stateless-chat/1379164 — user (one person)
- https://community.openai.com/t/projects-are-containers-not-archives-large-projects-need-retrieval-not-just-memory/1383739 — user
- https://community.openai.com/t/chatgpt-recalls-saved-memory-but-fails-to-apply-it-and-invents-plausible-context-instead-of-verifying-history/1393739 — user (added in review)
- https://every.to/also-true-for-humans/why-i-turned-off-chatgpt-s-memory — user (added in review)
- https://uk.trustpilot.com/review/claude.ai?page=4 — user
- https://nl-be.trustpilot.com/review/highlightai.com — user
- https://www.producthunt.com/products/littlebird/reviews — user (reviewers skew to founders and beta testers)
- https://techcrunch.com/2026/03/10/ai-powered-apps-struggle-with-long-term-retention-new-report-shows — summary
- https://www.revenuecat.com/blog/growth/ai-app-retention-study.md — summary
- https://dev.to/alichherawalla/what-to-build-in-your-edtech-app-when-better-test-scores-are-not-enough-to-retain-learners-1k78 — vendor
- https://ask.yipitdata.com/insights/chatgpt-claude-dual-subscriber-retention — summary (US e-receipt panel)
- https://www.ifun.de/raycast-veraergert-nutzer-mit-neuem-ki-preismodell-288857/ — user comment on a news article
- https://talk.macpowerusers.com/t/ray-cast-introduce-subscription-based-raycast-pro/33583 — user
- https://www.photools.com/community/index.php?msg=107216 — vendor (first quote, the developer) and user (second quote)
- https://feedback.clickup.com/feature-requests/p/please-remove-the-ai-that-is-giving-false-instructions — user
- https://news.ycombinator.com/item?id=50018817 — user (added in review)
- https://www.producthunt.com/p/clicky-3/clicky-4 — vendor (product list only)
- https://www.producthunt.com/p/spotit-3/are-ai-agents-that-do-things-for-you-actually-useful-or-do-you-prefer-tools-that-show-you-how — vendor (seen by the researcher; a maker's poll with no replies)
- https://news.ycombinator.com/item?id=43201878 — vendor (product list only)
- https://pcworld.com/article/2657888/copilot-vision-for-windows-can-walk-you-through-tech-issues-step-by-step.html — summary (seen by the researcher; press coverage)

### Q4

- https://news.ycombinator.com/item?id=49024620 — user
- https://news.ycombinator.com/item?id=40677424 — user (2024)
- https://andrewschreiber.substack.com/p/an-early-adopters-thoughts-on-rewindais — user, and summary where the author describes other users
- https://www.entrepreneur.com/business-news/meta-will-track-every-click-and-keystroke-employees-make-backlash — summary
- https://comparethecloud.net/articles/shadow-ai-uk-it-managers/ — summary
- https://www.kaspersky.com/blog/it-compliance-of-microsoft-copilot-recall-apple-intelligence-google-astra/51769 — vendor (2024)
- https://stacker.com/stories/business-economy/ai-notetakers-have-sat-1-3-us-workers-meetings-only-third-say-they-were — summary, commissioned by a law firm
- https://nudgesecurity.com/post/shadow-ai-is-taking-notes-the-growing-risk-of-ai-meeting-assistants — vendor
- https://agilebrandguide.com/resigned-consent-new-global-study-finds-consumers-grant-ai-access-reluctantly-more-than-twice-as-often-as-willingly/ — summary, commissioned by a consent-management vendor
- https://www.malwarebytes.com/blog/privacy/2026/03/90-of-people-dont-trust-ai-with-their-data — vendor
- https://www.producthunt.com/posts/clicky-2 — user
- https://www.schneier.com/?p=68947 — user comment (2024)
- https://forums.tomshardware.com/threads/microsoft-backtracks-on-new-recall-feature-%E2%80%94-enhancing-recalls-security-and-making-it-an-opt-in-decision.3846565/page-2 — user (2024)
- https://community.openai.com/t/privacy-concerns-in-chatgpts-memory-system/982636 — user (2024)
- https://elephas.app/resources/chatgpt-desktop-computer-history-privacy — vendor (a competitor's blog)
- https://blog.topedia.com/2026/06/vision-in-microsoft-365-copilot-screen-and-camera-sharing-on-desktop-and-mobile/ — summary (added in review)
- https://www.hrreporter.com/focus-areas/automation-ai/a-hard-no-next-wave-of-agentic-ai-upping-the-ante/394221 — summary (added in review)
- https://ppc.land/only-18-of-americans-trust-ai-with-their-data-meta-ai-leads/ — vendor survey (added in review)
- https://usercentrics.com/press/usercentrics-state-of-digital-trust-2026-report-us-findings/ — vendor (added in review)
- https://tidbits.com/2024/09/23/how-to-avoid-sequoias-repetitive-screen-recording-permissions-prompts/ — summary, with one user comment (added in review, 2024)
- https://9to5mac.com/2025/12/05/rewind-limitless-meta-acquisition/ — summary (product list only)
- https://gptprompts.ai/littlebird-ai-review — summary (price only; the reviewer did not test the app)
- https://www.usecarly.com/blog/cluely-vs-clicky/ — vendor (price only; a competitor's blog)
