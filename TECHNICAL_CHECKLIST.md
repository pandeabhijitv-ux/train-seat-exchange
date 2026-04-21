# Production Deployment Technical Checklist

## Phase 1: Infrastructure Setup (Week 1)

### Database
- [ ] Sign up for PostgreSQL hosting (Render/Railway/Supabase)
- [ ] Create production database
- [ ] Set up database backups (daily minimum)
- [ ] Configure connection pooling (10-20 connections)
- [ ] Enable SSL connections
- [ ] Create read-only user for analytics (optional)

**PostgreSQL Hosting Options:**
- Render.com: Free tier (90 days) → $7/month
- Railway.app: Free trial → $5/month
- Supabase: Free tier → $25/month
- AWS RDS: ~$15/month minimum

### Hosting Platform
- [ ] Choose platform (Render/Railway/Heroku/AWS)
- [ ] Set up account and payment
- [ ] Configure region (closest to users)
- [ ] Set up auto-scaling rules
- [ ] Configure minimum instances (1-2)

**Recommended Stack:**
```
Backend: Render.com Web Service ($7/month starter)
Database: Render PostgreSQL ($7/month)
Cache: Upstash Redis (Free tier)
Total: ~$14/month to start
```

### Domain & SSL
- [ ] Buy domain name (optional)
- [ ] Configure DNS settings
- [ ] SSL certificate (auto with Render/Railway)
- [ ] Set up www redirect
- [ ] Configure CDN (Cloudflare free tier)

## Phase 2: Security Configuration (Week 1-2)

### API Keys & Secrets
- [ ] Generate strong SECRET_KEY (32+ characters random)
- [ ] Get MSG91 production credentials
- [ ] Get Razorpay LIVE keys (not test)
- [ ] Get RapidAPI key
- [ ] Store all secrets in platform environment variables
- [ ] NEVER commit secrets to git

### Security Hardening
- [ ] Enable rate limiting (100 req/min per IP)
- [ ] Configure CORS with specific origins
- [ ] Add security headers
- [ ] Enable HTTPS only
- [ ] Set up IP whitelisting for admin (optional)
- [ ] Implement request signing/JWT tokens
- [ ] Add input validation on all endpoints
- [ ] Enable SQL injection protection
- [ ] Set up XSS protection

### Authentication
- [ ] OTP expiry configured (10 minutes)
- [ ] Failed login attempt tracking
- [ ] Account lockout after 5 failed attempts
- [ ] Session management
- [ ] Logout functionality

## Phase 3: Monitoring & Logging (Week 2)

### Error Tracking
- [ ] Sign up for Sentry.io (free tier: 5000 errors/month)
- [ ] Integrate Sentry SDK
- [ ] Configure error alerting
- [ ] Set up email notifications
- [ ] Test error capture

### Application Monitoring
- [ ] Set up health check endpoint (/health)
- [ ] Configure uptime monitoring (UptimeRobot free)
- [ ] Set up performance monitoring
- [ ] Configure alerts for:
  - Server down
  - High error rate (>1%)
  - High response time (>2s)
  - Database connection issues
  - Out of memory

### Logging
- [ ] Configure structured logging
- [ ] Set up log rotation (10MB max per file)
- [ ] Configure log levels (INFO in prod)
- [ ] Set up centralized logging (optional)
- [ ] Create logs/ directory with write permissions

### Analytics
- [ ] Add Google Analytics (optional)
- [ ] Track key events:
  - User signups
  - OTP verifications
  - Payments completed
  - Seat exchanges created
  - Search queries

## Phase 4: Performance Optimization (Week 2-3)

### Database Optimization
- [ ] Add indexes on frequently queried columns:
  ```sql
  CREATE INDEX idx_phone ON users(phone);
  CREATE INDEX idx_train_number ON entries(train_number);
  CREATE INDEX idx_status ON entries(status);
  CREATE INDEX idx_departure ON entries(departure_datetime);
  ```
- [ ] Enable query logging (temporarily)
- [ ] Analyze slow queries
- [ ] Optimize N+1 queries
- [ ] Configure query timeout (30s)

### Caching
- [ ] Set up Redis (Upstash free tier)
- [ ] Cache PNR verification results (1 hour)
- [ ] Cache train search results (5 minutes)
- [ ] Implement cache invalidation strategy
- [ ] Monitor cache hit rate (target >80%)

### API Performance
- [ ] Enable response compression (gzip)
- [ ] Implement pagination (max 50 items)
- [ ] Add database connection pooling
- [ ] Configure worker processes (2-4)
- [ ] Set request timeout (30s)
- [ ] Optimize JSON serialization

### CDN & Static Assets
- [ ] Use Cloudflare CDN (free)
- [ ] Enable caching for static files
- [ ] Compress images
- [ ] Minify CSS/JS
- [ ] Set cache headers

## Phase 5: Backup & Disaster Recovery (Week 3)

### Database Backups
- [ ] Enable automated daily backups
- [ ] Test backup restoration
- [ ] Set up point-in-time recovery
- [ ] Store backups in separate location
- [ ] Configure backup retention (30 days)
- [ ] Document backup restoration process

### Application Backups
- [ ] Code in Git (GitHub/GitLab)
- [ ] Tag production releases
- [ ] Document deployment process
- [ ] Create rollback procedure
- [ ] Test rollback process

### Disaster Recovery Plan
- [ ] Document recovery procedures
- [ ] Set up staging environment
- [ ] Test full disaster recovery
- [ ] Define RTO (Recovery Time Objective): 1 hour
- [ ] Define RPO (Recovery Point Objective): 1 hour
- [ ] Maintain runbook for common issues

## Phase 6: Testing & QA (Week 3)

### Load Testing
- [ ] Install Apache Bench or k6
- [ ] Test with 100 concurrent users
- [ ] Test with 1000 concurrent users
- [ ] Measure response times under load
- [ ] Identify bottlenecks
- [ ] Test auto-scaling

### Security Testing
- [ ] Run OWASP ZAP scan
- [ ] Test SQL injection vulnerabilities
- [ ] Test XSS vulnerabilities
- [ ] Test authentication bypass
- [ ] Check for exposed secrets
- [ ] Verify HTTPS everywhere

### Integration Testing
- [ ] Test OTP flow end-to-end
- [ ] Test payment flow with real money (₹1)
- [ ] Test PNR verification
- [ ] Test search functionality
- [ ] Test with real phone number
- [ ] Test error scenarios

### User Acceptance Testing
- [ ] Beta test with 10-20 users
- [ ] Collect feedback
- [ ] Fix critical bugs
- [ ] Test on multiple devices
- [ ] Test on slow networks

## Phase 7: Compliance & Legal (Ongoing)

### Data Protection
- [ ] Implement data encryption at rest
- [ ] Implement data encryption in transit
- [ ] Configure data retention policy
- [ ] Set up GDPR compliance (if applicable)
- [ ] Implement data deletion on request
- [ ] Create privacy policy
- [ ] Create terms of service

### Payment Compliance
- [ ] Complete Razorpay KYC
- [ ] Configure webhook for payment notifications
- [ ] Test refund process
- [ ] Set up payment reconciliation
- [ ] Configure GST collection (if required)

### Audit Trail
- [ ] Log all payment transactions
- [ ] Log all data modifications
- [ ] Log authentication attempts
- [ ] Implement audit log retention (1 year)

## Phase 8: DevOps & Automation (Week 4)

### CI/CD Pipeline
- [ ] Set up GitHub Actions
- [ ] Configure automated testing
- [ ] Configure automated deployment
- [ ] Set up staging environment
- [ ] Implement blue-green deployment
- [ ] Configure rollback automation

### Infrastructure as Code
- [ ] Document infrastructure setup
- [ ] Create Terraform/Pulumi scripts (optional)
- [ ] Version control infrastructure configs
- [ ] Automate environment creation

### Monitoring Automation
- [ ] Set up automated health checks
- [ ] Configure auto-restart on failure
- [ ] Set up automated backups
- [ ] Configure automated alerts
- [ ] Create status page (statuspage.io)

## Infrastructure Costs Estimate

### Minimal Setup (MVP - $14-20/month)
```
Render Web Service:    $7/month  (512MB RAM, shared CPU)
Render PostgreSQL:     $7/month  (256MB RAM)
Upstash Redis:         Free      (10K commands/day)
Cloudflare CDN:        Free
UptimeRobot:           Free      (50 monitors)
Sentry.io:             Free      (5K errors/month)
-------------------
Total:                 $14/month
```

### Growing Setup ($50-80/month)
```
Render Web Service:    $25/month  (2GB RAM, 1 CPU)
Render PostgreSQL:     $20/month  (1GB RAM)
Redis (Upstash Pro):   $10/month
Domain name:           $1/month   (amortized)
Sentry Pro:            $26/month  (100K errors)
-------------------
Total:                 $82/month
```

### Scale Setup ($200-500/month)
```
AWS ECS/Fargate:       $100/month (auto-scaling)
RDS PostgreSQL:        $50/month  (db.t3.medium)
ElastiCache Redis:     $30/month
CloudFront CDN:        $10/month
DataDog monitoring:    $15/month
Load balancer:         $20/month
-------------------
Total:                 $225/month
```

## Performance Targets

### Response Times
- API endpoint: <200ms (p95)
- Database query: <50ms (p95)
- PNR verification: <2s
- Payment creation: <500ms

### Availability
- Uptime: 99.5% (3.6 hours downtime/month)
- Error rate: <0.5%
- Failed payments: <0.1%

### Scalability
- Support 100 concurrent users initially
- Handle 10K users/day
- Scale to 1000 concurrent users
- Database: 1M+ entries

## Critical Success Metrics

### Technical
- [ ] 99.5%+ uptime
- [ ] <2s average response time
- [ ] <1% error rate
- [ ] Zero security incidents
- [ ] <5min deployment time

### Business
- [ ] <5% payment failure rate
- [ ] >90% OTP delivery rate
- [ ] >50% PNR verification success
- [ ] <10s user onboarding time

## Pre-Launch Checklist

### 24 Hours Before Launch
- [ ] Final security audit
- [ ] Backup verification
- [ ] Load testing complete
- [ ] Monitoring configured
- [ ] Support email set up
- [ ] Emergency contacts documented
- [ ] Rollback plan tested

### Launch Day
- [ ] Deploy to production
- [ ] Verify all endpoints
- [ ] Test payment flow
- [ ] Monitor error rates
- [ ] Check logs continuously
- [ ] Have team on standby

### Week 1 Post-Launch
- [ ] Daily monitoring checks
- [ ] Review error logs
- [ ] Analyze user feedback
- [ ] Fix critical bugs
- [ ] Optimize performance
- [ ] Plan next features

## Quick Reference Commands

### Deploy to Production
```bash
git push origin main  # Triggers auto-deploy
```

### Check application health
```bash
curl https://your-app.com/health
curl https://your-app.com/metrics
```

### View logs
```bash
# On Render
render logs -t train-seat-exchange-api

# On Railway
railway logs
```

### Database backup
```bash
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d).sql
```

### Test load
```bash
ab -n 1000 -c 100 https://your-app.com/api/v1/health
```

## Support Contacts

- **Hosting**: support@render.com
- **Database**: database-support@render.com
- **Razorpay**: support@razorpay.com
- **MSG91**: support@msg91.com
- **Emergency**: Keep on-call rotation
