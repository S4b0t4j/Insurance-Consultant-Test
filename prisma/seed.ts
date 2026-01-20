import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting seed...');

  // Clear existing data
  await prisma.sledSignal.deleteMany();
  await prisma.user.deleteMany();

  // Create users
  const adminUser = await prisma.user.create({
    data: {
      email: 'admin@sledinsurance.com',
      name: 'Admin User',
      role: 'ADMIN',
    },
  });

  const viewerUser = await prisma.user.create({
    data: {
      email: 'viewer@sledinsurance.com',
      name: 'Viewer User',
      role: 'VIEWER',
    },
  });

  console.log('✅ Created users');

  // Create SLED signals
  const signals = [
    {
      headline: 'California Passes AB 1234: Mandatory Cyber Disclosure for School Districts',
      summary:
        'New legislation requires all K-12 districts to report cyber incidents within 72 hours to state authorities. The bill also mandates annual cybersecurity assessments and staff training. Districts must implement multi-factor authentication for all systems by January 2027. Non-compliance could result in funding penalties.',
      sourceUrl: 'https://example.com/ca-ab-1234',
      sourcePublication: 'EdTech Today',
      publishedAt: new Date('2026-01-15'),
      entityCategory: 'EDUCATION' as const,
      entityType: 'SCHOOL_DISTRICT' as const,
      jurisdiction: 'California',
      insuranceLines: ['CYBER' as const],
      riskDriverType: 'REGULATORY' as const,
      severityLevel: 'HIGH' as const,
      whyItMatters:
        'School districts renewing cyber coverage in CA will face stricter compliance requirements. Expect premium adjustments and enhanced questionnaires at renewal. Discuss incident response plans with clients now.',
      createdBy: adminUser.id,
    },
    {
      headline: 'Texas Municipal Utility District Faces $12M Wildfire Claim',
      summary:
        'Harris County MUD #42 named in lawsuit alleging vegetation management failures contributed to 2025 wildfire that destroyed 45 homes. Plaintiffs claim the district failed to maintain firebreaks and ignored prior warnings from fire officials.',
      sourceUrl: 'https://example.com/tx-mud-wildfire',
      sourcePublication: 'Texas Municipal News',
      publishedAt: new Date('2026-01-10'),
      entityCategory: 'LOCAL' as const,
      entityType: 'UTILITY' as const,
      jurisdiction: 'Harris County, TX',
      insuranceLines: ['GENERAL_LIABILITY' as const, 'EXCESS' as const],
      riskDriverType: 'LITIGATION' as const,
      severityLevel: 'HIGH' as const,
      whyItMatters:
        'Wildfire liability exposure expanding to utilities. Review excess tower adequacy for MUD clients in wildfire-prone areas. Consider vegetation management protocols as underwriting requirement.',
    },
    {
      headline: 'Florida Supreme Court Expands Police Liability in Pursuit Cases',
      summary:
        'Landmark ruling in Martinez v. City of Tampa establishes that municipalities can be held liable for injuries to bystanders during high-speed pursuits, even when officers followed department policy. Decision affects all Florida cities and counties with police departments.',
      sourceUrl: 'https://example.com/fl-pursuit-ruling',
      sourcePublication: 'Florida Law Review',
      publishedAt: new Date('2026-01-08'),
      entityCategory: 'LOCAL' as const,
      entityType: 'MUNICIPALITY' as const,
      jurisdiction: 'Florida',
      insuranceLines: ['GENERAL_LIABILITY' as const, 'EXCESS' as const],
      riskDriverType: 'LITIGATION' as const,
      severityLevel: 'HIGH' as const,
      whyItMatters:
        'Florida municipalities will see immediate impact on general liability pricing. Review pursuit policies with all Florida clients. Expect carriers to request policy documentation and training records.',
    },
    {
      headline: 'Public University System Announces $50M Budget Shortfall',
      summary:
        'New York State University System faces significant budget cuts due to declining enrollment and reduced state funding. System plans to defer maintenance on 30+ facilities and reduce facility operations staff by 15%. Deferred maintenance backlog now exceeds $2B.',
      sourceUrl: 'https://example.com/ny-university-budget',
      sourcePublication: 'Higher Ed Insider',
      publishedAt: new Date('2026-01-05'),
      entityCategory: 'EDUCATION' as const,
      entityType: 'PUBLIC_UNIVERSITY' as const,
      jurisdiction: 'New York',
      insuranceLines: ['PROPERTY' as const, 'GENERAL_LIABILITY' as const],
      riskDriverType: 'FINANCIAL' as const,
      severityLevel: 'MEDIUM' as const,
      whyItMatters:
        'Deferred maintenance increases property loss exposure. Proactively discuss facility condition with university clients. Consider property inspection as condition for renewal.',
    },
    {
      headline: 'Michigan Transit Authority Hit with $8M ADA Discrimination Lawsuit',
      summary:
        'Detroit Regional Transit Authority faces class-action lawsuit from disability advocacy groups alleging systematic failures to provide accessible transportation. Suit claims over 40% of bus lifts non-functional and drivers inadequately trained on ADA compliance.',
      sourceUrl: 'https://example.com/mi-transit-ada',
      sourcePublication: 'Transit Weekly',
      publishedAt: new Date('2025-12-28'),
      entityCategory: 'LOCAL' as const,
      entityType: 'TRANSIT_AUTHORITY' as const,
      jurisdiction: 'Detroit, MI',
      insuranceLines: ['GENERAL_LIABILITY' as const, 'EPLI' as const],
      riskDriverType: 'LITIGATION' as const,
      severityLevel: 'HIGH' as const,
      whyItMatters:
        'ADA compliance becoming major liability driver for transit agencies. Review fleet maintenance records and training documentation with transit clients. Consider targeted risk management recommendations.',
    },
    {
      headline: 'Colorado School District Cyber Attack Exposes 50K Student Records',
      summary:
        'Jefferson County Schools confirms ransomware attack compromised student and staff personal information including Social Security numbers. District declined to pay $500K ransom. Investigation reveals vulnerability exploited due to unpatched software.',
      sourceUrl: 'https://example.com/co-school-cyber',
      sourcePublication: 'Cybersecurity Today',
      publishedAt: new Date('2025-12-20'),
      entityCategory: 'EDUCATION' as const,
      entityType: 'SCHOOL_DISTRICT' as const,
      jurisdiction: 'Jefferson County, CO',
      insuranceLines: ['CYBER' as const, 'PROFESSIONAL_LIABILITY' as const],
      riskDriverType: 'OPERATIONAL' as const,
      severityLevel: 'HIGH' as const,
      whyItMatters:
        'Large-scale breach demonstrates vulnerability of school districts. Use as case study with education clients. Review cyber policy limits and patch management protocols.',
    },
    {
      headline: 'Illinois Raises Workers Comp Benefits for First Responders',
      summary:
        'New state law increases presumptive coverage for PTSD and extends benefits for cancer diagnoses among firefighters and police officers. Municipalities must now cover mental health treatment without waiting period. Applies retroactively to claims filed after January 1, 2025.',
      sourceUrl: 'https://example.com/il-workers-comp',
      sourcePublication: 'Illinois Municipal Review',
      publishedAt: new Date('2025-12-15'),
      entityCategory: 'LOCAL' as const,
      entityType: 'MUNICIPALITY' as const,
      jurisdiction: 'Illinois',
      insuranceLines: ['WORKERS_COMP' as const],
      riskDriverType: 'REGULATORY' as const,
      severityLevel: 'MEDIUM' as const,
      whyItMatters:
        'Illinois municipalities will see workers comp rate increases. Proactively notify clients of new requirements. Consider wellness program implementation to mitigate long-term costs.',
    },
    {
      headline: 'Charter School Network Files Bankruptcy After Enrollment Collapse',
      summary:
        'Arizona-based charter network operating 12 schools files Chapter 11 after losing 35% enrollment post-pandemic. Network owes $15M to vendors and faces multiple employment-related lawsuits. State education board investigating financial management practices.',
      sourceUrl: 'https://example.com/az-charter-bankruptcy',
      sourcePublication: 'Charter School Quarterly',
      publishedAt: new Date('2025-12-10'),
      entityCategory: 'EDUCATION' as const,
      entityType: 'CHARTER_SCHOOL' as const,
      jurisdiction: 'Arizona',
      insuranceLines: ['D_AND_O' as const, 'EPLI' as const],
      riskDriverType: 'FINANCIAL' as const,
      severityLevel: 'HIGH' as const,
      whyItMatters:
        'Charter school financial instability creates D&O and EPLI exposure. Review enrollment trends and financial health with charter clients. Consider financial stress testing as underwriting requirement.',
    },
    {
      headline: 'State Agency Data Center Suffers Major Outage After Flooding',
      summary:
        'Pennsylvania Department of Transportation data center offline for 72 hours after HVAC failure and water damage. Incident disrupted license renewals and vehicle registrations statewide. Preliminary damage estimate exceeds $3M. Investigation reveals deferred maintenance on aging cooling systems.',
      sourceUrl: 'https://example.com/pa-agency-outage',
      sourcePublication: 'Government Technology',
      publishedAt: new Date('2025-12-05'),
      entityCategory: 'STATE' as const,
      entityType: 'STATE_AGENCY' as const,
      jurisdiction: 'Pennsylvania',
      insuranceLines: ['PROPERTY' as const, 'CYBER' as const],
      riskDriverType: 'OPERATIONAL' as const,
      severityLevel: 'MEDIUM' as const,
      whyItMatters:
        'Demonstrates business interruption exposure for state agencies. Discuss disaster recovery plans and equipment maintenance with agency clients. Review property policy business interruption limits.',
    },
    {
      headline: 'Oregon County Settles Sexual Harassment Case for $2.5M',
      summary:
        'Multnomah County reaches settlement with former employee who alleged hostile work environment and retaliation. Case involved multiple supervisors and spanned three years. County also agrees to implement comprehensive harassment training and establish independent reporting hotline.',
      sourceUrl: 'https://example.com/or-county-epli',
      sourcePublication: 'HR Legal Alert',
      publishedAt: new Date('2025-12-01'),
      entityCategory: 'LOCAL' as const,
      entityType: 'COUNTY' as const,
      jurisdiction: 'Multnomah County, OR',
      insuranceLines: ['EPLI' as const],
      riskDriverType: 'LITIGATION' as const,
      severityLevel: 'MEDIUM' as const,
      whyItMatters:
        'EPLI claims severity increasing for public entities. Review harassment prevention policies with county clients. Discuss training documentation requirements for underwriting.',
    },
    {
      headline: 'Community College Faces Title IX Investigation Over Athletic Program',
      summary:
        'Federal investigation launched into allegations of gender inequity in athletic facilities and funding at California community college. OCR complaint alleges female athletes receive inferior equipment, facilities, and scholarship support.',
      sourceUrl: 'https://example.com/ca-title-ix',
      sourcePublication: 'Community College Times',
      publishedAt: new Date('2025-11-28'),
      entityCategory: 'EDUCATION' as const,
      entityType: 'COMMUNITY_COLLEGE' as const,
      jurisdiction: 'California',
      insuranceLines: ['PROFESSIONAL_LIABILITY' as const, 'D_AND_O' as const],
      riskDriverType: 'REGULATORY' as const,
      severityLevel: 'MEDIUM' as const,
      whyItMatters:
        'Title IX compliance emerging as professional liability issue. Discuss athletic program equity with higher ed clients. Review policy language for regulatory defense coverage.',
    },
    {
      headline: 'Major Hurricane Causes $500M in Damage to Gulf Coast School Districts',
      summary:
        'Hurricane Rafael causes catastrophic damage to 85 school facilities across three Louisiana parishes. Estimated repair costs exceed district insurance capacity. FEMA assistance expected but may take months. Several schools may not reopen until next academic year.',
      sourceUrl: 'https://example.com/la-hurricane-schools',
      sourcePublication: 'Disaster Recovery News',
      publishedAt: new Date('2025-11-20'),
      entityCategory: 'EDUCATION' as const,
      entityType: 'SCHOOL_DISTRICT' as const,
      jurisdiction: 'Louisiana',
      insuranceLines: ['PROPERTY' as const],
      riskDriverType: 'CATASTROPHE' as const,
      severityLevel: 'HIGH' as const,
      whyItMatters:
        'Major CAT event affecting multiple education clients. Coordinate claims support across impacted districts. Review adequacy of replacement cost coverage for coastal clients.',
    },
    {
      headline: 'Washington State Mandates Electric Vehicle Fleet Conversion for Cities',
      summary:
        'New law requires all municipalities to transition 50% of non-emergency fleet to electric vehicles by 2028. Cities must install charging infrastructure and train mechanics on EV systems. State provides limited grant funding but most costs fall to local budgets.',
      sourceUrl: 'https://example.com/wa-ev-mandate',
      sourcePublication: 'Municipal Fleet Management',
      publishedAt: new Date('2025-11-15'),
      entityCategory: 'LOCAL' as const,
      entityType: 'MUNICIPALITY' as const,
      jurisdiction: 'Washington',
      insuranceLines: ['AUTO' as const, 'PROPERTY' as const],
      riskDriverType: 'REGULATORY' as const,
      severityLevel: 'MEDIUM' as const,
      whyItMatters:
        'EV transition creates new property and auto exposures. Discuss charging infrastructure with WA municipal clients. Review auto policy language for EV battery coverage.',
    },
    {
      headline: 'Special District Board Members Charged with Misappropriation of Funds',
      summary:
        'Three board members of California irrigation district indicted for allegedly diverting $1.2M in public funds for personal use. Investigation began after whistleblower complaint. Civil lawsuit by district seeking recovery also filed.',
      sourceUrl: 'https://example.com/ca-district-fraud',
      sourcePublication: 'Public Finance Journal',
      publishedAt: new Date('2025-11-10'),
      entityCategory: 'LOCAL' as const,
      entityType: 'SPECIAL_DISTRICT' as const,
      jurisdiction: 'California',
      insuranceLines: ['D_AND_O' as const],
      riskDriverType: 'LITIGATION' as const,
      severityLevel: 'HIGH' as const,
      whyItMatters:
        'Board misconduct claims highlight D&O exposure for special districts. Review governance controls with district clients. Discuss fidelity bond adequacy and D&O policy sublimits.',
    },
    {
      headline: 'Federal Court Rules Against University in Free Speech Lawsuit',
      summary:
        'Virginia public university ordered to pay $500K in damages after court finds administrators violated student group\'s First Amendment rights by denying event permits. Decision establishes new precedent for viewpoint discrimination claims against universities.',
      sourceUrl: 'https://example.com/va-university-speech',
      sourcePublication: 'Higher Education Law Review',
      publishedAt: new Date('2025-11-05'),
      entityCategory: 'EDUCATION' as const,
      entityType: 'PUBLIC_UNIVERSITY' as const,
      jurisdiction: 'Virginia',
      insuranceLines: ['PROFESSIONAL_LIABILITY' as const, 'D_AND_O' as const],
      riskDriverType: 'LITIGATION' as const,
      severityLevel: 'MEDIUM' as const,
      whyItMatters:
        'First Amendment litigation increasing for universities. Discuss event approval policies with higher ed clients. Review professional liability coverage for constitutional claims.',
    },
  ];

  for (const signal of signals) {
    await prisma.sledSignal.create({
      data: signal,
    });
  }

  console.log(`✅ Created ${signals.length} SLED signals`);
  console.log('🎉 Seed completed successfully!');
}

main()
  .catch((e) => {
    console.error('Error seeding database:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
