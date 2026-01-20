import Link from 'next/link';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';

export default function Home() {
  return (
    <div className="min-h-screen bg-background">
      <header className="border-b bg-card">
        <div className="container mx-auto px-4 py-4">
          <h1 className="text-2xl font-bold">SLED Insurance Analytics</h1>
        </div>
      </header>

      <main className="container mx-auto px-4 py-16">
        <div className="max-w-4xl mx-auto space-y-12">
          <div className="text-center space-y-4">
            <h2 className="text-5xl font-bold tracking-tight">
              State, Local, and Education Insurance Intelligence
            </h2>
            <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
              Internal analytics dashboard for commercial insurance brokers focused on SLED public entities.
            </p>
            <div className="flex gap-4 justify-center pt-6">
              <Button asChild size="lg">
                <Link href="/dashboard">View Dashboard</Link>
              </Button>
              <Button asChild variant="outline" size="lg">
                <Link href="/admin">Admin Panel</Link>
              </Button>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 pt-8">
            <Card>
              <CardHeader>
                <CardTitle>State Entities</CardTitle>
                <CardDescription>
                  State agencies, authorities, and commissions
                </CardDescription>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-muted-foreground">
                  Track regulatory changes, litigation, and operational developments affecting state government entities.
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Local Government</CardTitle>
                <CardDescription>
                  Cities, counties, and special districts
                </CardDescription>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-muted-foreground">
                  Monitor liability trends, infrastructure risks, and emerging exposures for municipalities.
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Education</CardTitle>
                <CardDescription>
                  K-12, charter schools, and public universities
                </CardDescription>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-muted-foreground">
                  Stay informed on cyber risks, employment issues, and regulatory compliance for educational institutions.
                </p>
              </CardContent>
            </Card>
          </div>

          <Card className="bg-muted">
            <CardHeader>
              <CardTitle>Key Features</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <li className="flex items-start gap-2">
                  <span className="text-primary font-bold">✓</span>
                  <span>Filter by entity category, type, and jurisdiction</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-primary font-bold">✓</span>
                  <span>Search by insurance line coverage</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-primary font-bold">✓</span>
                  <span>Plain English "Why It Matters" insights</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-primary font-bold">✓</span>
                  <span>Severity-based risk prioritization</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-primary font-bold">✓</span>
                  <span>Admin panel for signal management</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-primary font-bold">✓</span>
                  <span>Responsive design for desktop and tablet</span>
                </li>
              </ul>
            </CardContent>
          </Card>

          <div className="text-center text-sm text-muted-foreground">
            <p>Internal prototype for insurance producers</p>
            <p>No client PII or confidential data</p>
          </div>
        </div>
      </main>
    </div>
  );
}
